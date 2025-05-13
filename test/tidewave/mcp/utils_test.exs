defmodule Tidewave.MCP.UtilsTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Utils

  describe "truncate_lines/1" do
    test "truncates lines that are too long" do
      assert Utils.truncate_lines(String.duplicate("a", 2011)) ==
               String.duplicate("a", 2000) <> " [11 characters truncated] ..."
    end
  end

  describe "detect_file_line_endings/1" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      lf_file = Path.join(tmp_dir, "lf.txt")
      crlf_file = Path.join(tmp_dir, "crlf.txt")
      mixed_file = Path.join(tmp_dir, "mixed.txt")

      File.write!(lf_file, "Hello\nWorld\n")
      File.write!(crlf_file, "Hello\r\nWorld\r\n")
      File.write!(mixed_file, "Hello\r\nWorld\nCool")

      {:ok, %{lf_file: lf_file, crlf_file: crlf_file, mixed_file: mixed_file}}
    end

    test "returns :lf if the file uses LF line endings", %{
      lf_file: lf_file,
      crlf_file: crlf_file,
      mixed_file: mixed_file
    } do
      assert :lf = Utils.detect_file_line_endings(lf_file)
      assert :crlf = Utils.detect_file_line_endings(crlf_file)
      # when equal, line feed wins
      assert :lf = Utils.detect_file_line_endings(mixed_file)
    end
  end
end
