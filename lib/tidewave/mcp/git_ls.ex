defmodule Tidewave.MCP.GitLS do
  @moduledoc false

  alias Tidewave.MCP

  def list_files(glob_pattern \\ nil, no_gitignore \\ false) do
    execute_git(fn git_dir -> list_files(git_dir, glob_pattern, no_gitignore) end)
  end

  def detect_line_endings do
    execute_git(&detect_line_endings/1)
  end

  defp execute_git(fun) do
    cond do
      !System.find_executable("git") ->
        {:error, "This tool requires git to be installed and available in the PATH."}

      File.dir?(".git") ->
        fun.(nil)

      true ->
        # create an empty git repo to run ls-files
        tmp_dir = Path.join(Mix.Project.build_path(), "tmp")
        git_dir = Path.join(tmp_dir, ".git")

        if !File.dir?(git_dir) do
          {_, 0} = System.cmd("git", ["init", tmp_dir])
        end

        fun.(git_dir)
    end
  end

  defp list_files(git_dir, glob_pattern, no_gitignore) do
    args = if git_dir, do: ["--git-dir", git_dir], else: []
    args = args ++ ["ls-files", "--cached", "--others"]
    args = if !no_gitignore, do: args ++ ["--exclude-standard"], else: args
    args = if glob_pattern, do: args ++ [glob_pattern], else: args

    with {result, 0} <- System.cmd("git", args, cd: MCP.root()) do
      {:ok, String.split(result, "\n", trim: true)}
    else
      {error, exit_code} -> {:error, "Command failed with exit code #{exit_code}: #{error}"}
    end
  end

  defp detect_line_endings(git_dir) do
    args = if git_dir, do: ["--git-dir", git_dir], else: []
    args = args ++ ["ls-files", "--cached", "--others", "--exclude-standard", "--eol"]

    with {result, 0} <- System.cmd("git", args, cd: MCP.root()) do
      {:ok, parse_line_endings(result)}
    else
      {error, exit_code} -> {:error, "Command failed with exit code #{exit_code}: #{error}"}
    end
  end

  # https://github.com/git/git/commit/a7630bd4274a0dff7cff8b92de3d3f064e321359
  #
  # The end of line ("eolinfo") are shown like this:
  #
  #   "-text"        binary (or with bare CR) file
  #   "none"         text file without any EOL
  #   "lf"           text file with LF
  #   "crlf"         text file with CRLF
  #   "mixed"        text file with mixed line endings.
  #
  defp parse_line_endings(result) do
    # we ignore the mixed count for now
    {lf_count, crlf_count, _mixed_count} =
      for line <- String.split(result, "\n", trim: true),
          [_index_eolinfo, working_tree_eolinfo, _attr, _path] =
            String.split(line, " ", trim: true),
          reduce: {0, 0, 0} do
        {lf_count, crlf_count, mixed_count} ->
          case working_tree_eolinfo do
            "w/lf" -> {lf_count + 1, crlf_count, mixed_count}
            "w/crlf" -> {lf_count, crlf_count + 1, mixed_count}
            "w/mixed" -> {lf_count, crlf_count, mixed_count + 1}
            _ -> {lf_count, crlf_count, mixed_count}
          end
      end

    if lf_count >= crlf_count do
      :lf
    else
      :crlf
    end
  end
end
