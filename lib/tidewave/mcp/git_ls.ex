defmodule Tidewave.MCP.GitLS do
  @moduledoc false

  alias Tidewave.MCP

  def list_files(opts \\ []) do
    glob_pattern = Keyword.get(opts, :glob)
    include_ignored = Keyword.get(opts, :include_ignored, false)

    args = ["ls-files", "--cached", "--others"]
    args = if glob_pattern, do: args ++ [glob_pattern], else: args
    args = if include_ignored, do: args, else: args ++ ["--exclude-standard"]

    with {result, 0} <- System.cmd("git", args, cd: MCP.root()) do
      {:ok, String.split(result, "\n", trim: true)}
    else
      {error, exit_code} -> {:error, "Command failed with exit code #{exit_code}: #{error}"}
    end
  end

  def detect_line_endings do
    args = ["ls-files", "--cached", "--others", "--exclude-standard", "--eol"]

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
      for line <- String.split(result, "\n", trim: true), reduce: {0, 0, 0} do
        {lf_count, crlf_count, mixed_count} ->
          [_index_eolinfo, working_tree_eolinfo | _attrs_and_path] =
            String.split(line, " ", trim: true)

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
