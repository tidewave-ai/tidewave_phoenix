defmodule Tidewave.MCP.Tools.FS do
  @moduledoc false

  alias Tidewave.MCP
  alias Tidewave.MCP.GitLS
  alias Tidewave.MCP.Utils

  def ripgrep_executable, do: System.find_executable("rg")

  def tools do
    [
      %{
        name: "list_project_files",
        description: """
        Returns a list of files in the project.

        By default, when no arguments are passed, it returns all files in the project that
        are not ignored by .gitignore.

        Optionally, a glob_pattern can be passed to filter this list. When a pattern is passed,
        the gitignore check will be skipped.
        """,
        inputSchema: %{
          type: "object",
          properties: %{
            glob_pattern: %{
              type: "string",
              description:
                "Optional: a glob pattern to filter the listed files. If a pattern is passed, the .gitignore check will be skipped."
            }
          },
          required: []
        },
        callback: &list_project_files/1,
        listable: &listable/1
      },
      %{
        name: "read_project_file",
        description: """
        Returns the contents of the given file.

        Supports an optional line_offset and count. To read the full file, only the path needs to be passed.

        For security reasons, this tool only works for files that are relative to the project root: #{MCP.root()}.
        """,
        inputSchema: %{
          type: "object",
          required: ["path"],
          properties: %{
            path: %{
              type: "string",
              description: "The path to the file to read. It is relative to the project root."
            },
            line_offset: %{
              type: "integer",
              description: "Optional: the starting line offset from which to read. Defaults to 0."
            },
            count: %{
              type: "integer",
              description: "Optional: the number of lines to read. Defaults to all."
            }
          }
        },
        callback: &read_project_file/2,
        listable: &listable/1
      },
      %{
        name: "write_project_file",
        description: """
        Writes a file to the file system. If the file already exists, it will be overwritten.

        Before writing to a file, ensure it was read using the `read_project_file` tool.
        """,
        inputSchema: %{
          type: "object",
          required: ["path", "content"],
          properties: %{
            path: %{
              type: "string",
              description: "The path to the file to write. It is relative to the project root."
            },
            content: %{
              type: "string",
              description: "The content to write to the file"
            }
          }
        },
        callback: &write_project_file/2,
        listable: &listable/1
      },
      %{
        name: "edit_project_file",
        description: """
        A tool for editing parts of a file. It can find and replace text inside a file.
        For moving or deleting files, use the shell_eval tool with 'mv' or 'rm' instead.

        For large edits, use the write_project_file tool instead and overwrite the entire file.

        Before editing, ensure to read the source file using the read_project_file tool.

        To use this tool, provide the path to the file, the old_string to search for, and the new_string to replace it with.
        If the old_string is found multiple times, an error will be returned. To ensure uniqueness, include a couple of lines
        before and after the edit. All whitespace must be preserved as in the original file.

        This tool can only do a single edit at a time. If you need to make multiple edits, you can create a message with
        multiple tool calls to this tool, ensuring that each one contains enough context to uniquely identify the edit.
        """,
        inputSchema: %{
          type: "object",
          required: ["path", "old_string", "new_string"],
          properties: %{
            path: %{
              type: "string",
              description: "The path to the file to edit. It is relative to the project root."
            },
            old_string: %{
              type: "string",
              description: "The string to search for"
            },
            new_string: %{
              type: "string",
              description: "The string to replace the old_string with"
            }
          }
        },
        callback: &edit_project_file/2,
        listable: &listable/1
      },
      %{
        name: "grep_project_files",
        description:
          "Searches for text patterns in files using #{if ripgrep_executable(), do: "ripgrep", else: "a grep variant"}.",
        inputSchema: %{
          type: "object",
          required: ["pattern"],
          properties: %{
            pattern: %{
              type: "string",
              description: "The pattern to search for"
            },
            glob: %{
              type: "string",
              description:
                "Optional glob pattern to filter which files to search in, e.g., \"**/*.ex\". Note that if a glob pattern is used, the .gitignore file will be ignored."
            },
            case_sensitive: %{
              type: "boolean",
              description: "Whether the search should be case-sensitive. Defaults to false."
            },
            max_results: %{
              type: "integer",
              description: "Maximum number of results to return. Defaults to 100."
            }
          }
        },
        callback: &grep_project_files/2,
        listable: &listable/1
      }
    ]
  end

  defp listable(connect_params) do
    not is_nil(connect_params["include_fs_tools"])
  end

  def list_project_files(args) do
    case args do
      %{"glob_pattern" => glob_pattern} ->
        git_ls_files(glob_pattern)

      _ ->
        git_ls_files(nil)
    end
  end

  defp git_ls_files(glob_pattern) do
    with {:ok, files} <- GitLS.list_files(glob_pattern) do
      case files do
        [] ->
          {:ok, "No files found."}

        files ->
          {:ok, Enum.join(files, "\n")}
      end
    end
  end

  def read_project_file(args, assigns) do
    case args do
      %{"path" => path} ->
        line_offset = Map.get(args, "line_offset", 0)
        count = Map.get(args, "count")

        with {:ok, content} <- get_file_content(path, line_offset, count, !args["raw"]) do
          stat = File.stat!(path, time: :posix)

          assigns =
            Map.update(
              assigns,
              :read_timestamps,
              %{path => stat.mtime},
              &Map.put(&1, path, stat.mtime)
            )

          {:ok, content, assigns, %{mtime: stat.mtime}}
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp safe_path(path) do
    case Path.relative_to(path, MCP.root()) |> Path.safe_relative() do
      {:ok, path} ->
        {:ok, path}

      :error ->
        {:error,
         "The path is invalid or not relative to the project root. " <>
           "Files outside the root cannot be read for security reasons."}
    end
  end

  defp check_stale(path, read_timestamps, allow_not_found \\ false) do
    case File.stat(path, time: :posix) do
      {:error, :enoent} ->
        if allow_not_found, do: :ok, else: {:error, "File does not exist"}

      {:ok, stat} ->
        cond do
          is_nil(read_timestamps[path]) ->
            {:error,
             "File has not been read yet. Use read_project_file first to before overwriting it!"}

          stat.mtime > read_timestamps[path] ->
            {:error,
             "File has been modified since last read. Use read_project_file first to read it again!"}

          true ->
            :ok
        end
    end
  end

  def write_project_file(args, assigns) do
    case args do
      %{"path" => path, "content" => content} ->
        read_timestamps = timestamps_from_args_or_assigns(args, assigns)

        with {:ok, path} <- safe_path(path),
             :ok <- check_stale(path, read_timestamps, true) do
          do_write_file(path, content, assigns)
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  def edit_project_file(
        args,
        assigns
      ) do
    case args do
      %{"path" => path, "old_string" => old_string, "new_string" => new_string} ->
        read_timestamps = timestamps_from_args_or_assigns(args, assigns)

        with {:ok, path} <- safe_path(path),
             :ok <- check_stale(path, read_timestamps),
             old_content = File.read!(path),
             :ok <- ensure_one_match(old_content, old_string) do
          new_content = String.replace(old_content, old_string, new_string)
          do_write_file(path, new_content, assigns)
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp timestamps_from_args_or_assigns(args, assigns) do
    read_timestamps = Map.get(assigns, :read_timestamps, %{})

    case args do
      %{"atime" => posix} when is_integer(posix) ->
        Map.put(read_timestamps, args["path"], posix)

      _ ->
        read_timestamps
    end
  end

  defp ensure_one_match(content, substring) do
    case :binary.matches(content, substring) do
      [_] ->
        :ok

      [] ->
        {:error, "The original substring was not found in the file. No edits were made."}

      [_ | _] = matches ->
        {:error,
         "The substring was found more than once (#{Enum.count(matches)} times) in the file. No edits were made. Ensure uniqueness by providing more context."}
    end
  end

  defp do_write_file(path, content, assigns) do
    assigns = ensure_default_line_endings(assigns)

    content =
      case Utils.detect_file_line_endings(path) || assigns.default_line_endings do
        :crlf -> String.replace(content, ["\r\n", "\n"], "\r\n")
        :lf -> content
      end

    File.mkdir_p!(Path.dirname(path))

    try do
      content = maybe_autoformat(assigns, path, content)
      File.write!(path, content)
      stat = File.stat!(path, time: :posix)

      assigns =
        Map.update(
          assigns,
          :read_timestamps,
          %{path => stat.mtime},
          &Map.put(&1, path, stat.mtime)
        )

      {:ok, "Success!", assigns, %{mtime: stat.mtime}}
    rescue
      e -> {:error, "Failed to format file: #{Exception.format(:error, e, __STACKTRACE__)}"}
    end
  end

  defp maybe_autoformat(assigns, path, content) do
    if Map.get(assigns, :autoformat, true) do
      {fun, _opts} = Mix.Tasks.Format.formatter_for_file(path, root: MCP.root())
      fun.(content)
    else
      content
    end
  end

  # Maximum file size for reading (256KB)
  @max_file_size 262_144

  defp get_file_content(path, offset, count, truncate?) do
    with {:ok, path} <- safe_path(path) do
      case File.stat(path) do
        {:ok, %{size: size}} when size > @max_file_size ->
          {:error,
           "File is too large to read (#{size} bytes). Maximum size is #{@max_file_size} bytes."}

        {:ok, %{type: :regular}} ->
          content = File.read!(path)

          if String.valid?(content) do
            content = maybe_apply_offset_and_count(content, offset, count)

            {:ok, if(truncate?, do: Utils.truncate_lines(content), else: content)}
          else
            {:error, "Cannot read file, because it contains invalid UTF-8 characters"}
          end

        {:ok, %{type: other}} ->
          {:error, "Cannot read non-regular file: #{other}"}

        {:error, :enoent} ->
          {:error, "File does not exist"}

        {:error, reason} ->
          {:error, "Failed to get file stats: #{reason}"}
      end
    end
  end

  defp maybe_apply_offset_and_count(content, 0, nil), do: content

  defp maybe_apply_offset_and_count(content, offset, count) do
    splitter_and_joiner =
      case Utils.detect_line_endings(content) do
        :lf -> "\n"
        :crlf -> "\r\n"
      end

    lines = String.split(content, splitter_and_joiner)

    lines
    |> Enum.drop(offset)
    |> take_all_or(count)
    |> Enum.join(splitter_and_joiner)
  end

  defp take_all_or(list, nil), do: list
  defp take_all_or(list, count), do: Enum.take(list, count)

  @doc """
  Searches for text patterns in files.
  Uses ripgrep if available, falling back to grep.

  ## Arguments
  * `pattern` - The pattern to search for
  * `glob` - Optional glob pattern to filter files
  * `case_sensitive` - Whether the search should be case-sensitive
  * `max_results` - Maximum number of results to return
  """
  def grep_project_files(arguments, tool \\ nil) do
    pattern = Map.fetch!(arguments, "pattern")
    glob_pattern = Map.get(arguments, "glob")
    case_sensitive = Map.get(arguments, "case_sensitive", false)
    max_results = Map.get(arguments, "max_results", 100)

    cond do
      tool == :ripgrep ->
        grep_with_ripgrep(pattern, glob_pattern, case_sensitive, max_results)

      tool == :elixir_grep ->
        MCP.Grep.grep(pattern, glob_pattern, case_sensitive, max_results)

      ripgrep_executable() != nil ->
        grep_with_ripgrep(pattern, glob_pattern, case_sensitive, max_results)

        MCP.Grep.grep(pattern, glob_pattern, case_sensitive, max_results)
    end
  rescue
    e ->
      {:error, "Error executing grep: #{Exception.format(:error, e, __STACKTRACE__)}"}
  end

  # Implementation using ripgrep
  defp grep_with_ripgrep(pattern, glob_pattern, case_sensitive, max_results) do
    args = [
      "--no-require-git",
      "--json",
      "--max-count=#{max_results}"
    ]

    # Add case-insensitive flag if needed
    args = if !case_sensitive, do: ["--ignore-case" | args], else: args

    # Add glob pattern if provided
    args =
      if glob_pattern do
        ["--glob", glob_pattern | args]
      else
        args
      end

    # Add the search pattern and execute
    args = args ++ [pattern, "."]

    case System.cmd(ripgrep_executable(), args, stderr_to_stdout: true, cd: MCP.root()) do
      {output, 0} ->
        matches =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_ripgrep_line/1)
          |> Enum.reject(&is_nil/1)

        {:ok, Jason.encode!(matches)}

      {error, _} ->
        # If pattern wasn't found, ripgrep returns exit code 1, but that's not an error for us
        if String.contains?(error, "No files were searched") do
          {:ok, "[]"}
        else
          {:error, "Error while searching: #{error}"}
        end
    end
  end

  defp parse_ripgrep_line(line) do
    case Jason.decode(line) do
      {:ok, json} ->
        case json do
          %{"type" => "match", "data" => data} ->
            path = data["path"]["text"]
            line_number = data["line_number"]
            content = data["lines"]["text"]

            %{
              "path" => path,
              "line" => line_number,
              "content" => Utils.truncate_lines(content)
            }

          _ ->
            nil
        end

      {:error, _} ->
        nil
    end
  end

  defp ensure_default_line_endings(assigns) do
    Map.put_new_lazy(assigns, :default_line_endings, fn ->
      case GitLS.detect_line_endings() do
        {:ok, default_line_endings} -> default_line_endings
        {:error, _} -> :lf
      end
    end)
  end
end
