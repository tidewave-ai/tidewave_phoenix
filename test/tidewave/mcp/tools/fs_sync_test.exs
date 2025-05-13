defmodule Tidewave.MCP.Tools.FSSyncTest do
  # we use File.cd to change the working directory, so these tests run synchronously
  use ExUnit.Case, async: false

  alias Tidewave.MCP.Tools.FS

  setup context do
    if tmp_dir = context[:tmp_dir] do
      # Change to the test directory to make grep search there
      original_dir = File.cwd!()
      File.cd!(tmp_dir)

      # also overwrite the stored MCP working directory
      old_root = Application.get_env(:tidewave, :root)
      Application.put_env(:tidewave, :root, tmp_dir)

      on_exit(fn ->
        # Restore original directory
        File.cd!(original_dir)
        Application.put_env(:tidewave, :root, old_root)
      end)

      %{test_dir: tmp_dir}
    else
      :ok
    end
  end

  for tool <- [:ripgrep, :elixir_grep] do
    describe "grep/1 with #{tool}" do
      @describetag tool
      @describetag :tmp_dir

      setup %{tmp_dir: tmp_dir} do
        files = [
          {"file1.txt", "This is a test file with TEST content."},
          {"file2.md", "Another file with different test content."},
          {"file3.ex", "Elixir file with TEST pattern."},
          {Path.join("subdir", "file4.ex"), "Nested file with test content."}
        ]

        Enum.each(files, fn {file, content} ->
          full_path = Path.join(tmp_dir, file)
          File.mkdir_p!(Path.dirname(full_path))
          File.write!(full_path, content)
        end)
      end

      test "finds text matches with default options" do
        arguments = %{"pattern" => "test"}
        assert {:ok, text} = FS.grep_project_files(arguments, unquote(tool))

        # Should find all files (case-insensitive by default)
        assert text =~ "file1.txt"
        assert text =~ "file2.md"
        assert text =~ "file3.ex"
        assert text =~ "file4.ex"
      end

      test "respects case sensitivity" do
        arguments = %{"pattern" => "TEST", "case_sensitive" => true}
        assert {:ok, text} = FS.grep_project_files(arguments, unquote(tool))

        # Should only find files with uppercase TEST
        assert text =~ "file1.txt"
        assert text =~ "file3.ex"
        refute text =~ "file2.md"
        refute text =~ "file4.ex"
      end

      test "uses glob pattern to filter files" do
        arguments = %{"pattern" => "test", "glob" => "*.ex"}
        assert {:ok, text} = FS.grep_project_files(arguments, unquote(tool))

        # Should only find .ex files
        assert text =~ "file3.ex"
        refute text =~ "file1.txt"
        refute text =~ "file2.md"
      end

      test "respects .gitignore" do
        File.write!(".gitignore", "*.txt")
        assert {:ok, text} = FS.grep_project_files(%{"pattern" => "test"}, unquote(tool))

        refute text =~ "file1.txt"
        assert text =~ "file2.md"
        assert text =~ "file3.ex"
        assert text =~ "file4.ex"
      end
    end
  end

  describe "list_project_files/1 with glob pattern" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      files = [
        "file1.txt",
        "file2.md",
        "file3.ex",
        Path.join("subdir", "file4.ex")
      ]

      Enum.each(files, fn file ->
        full_path = Path.join(tmp_dir, file)
        File.mkdir_p!(Path.dirname(full_path))
        File.write!(full_path, "Test content for #{file}")
      end)
    end

    test "finds files matching pattern" do
      assert {:ok, text} = FS.list_project_files(%{"glob_pattern" => "*.txt"})

      assert text =~ "file1.txt"
      refute text =~ "file2.md"
    end

    test "finds files with wildcard pattern" do
      assert {:ok, text} = FS.list_project_files(%{"glob_pattern" => "*.ex"})

      assert text =~ "file3.ex"
      assert text =~ "file4.ex"
      refute text =~ "file1.txt"
    end

    test "ignores .gitignore when passing a glob_pattern" do
      File.write!(".gitignore", "*.txt")

      assert {:ok, text} =
               FS.list_project_files(%{"glob_pattern" => "*.txt"})

      assert text =~ "file1.txt"
    end
  end
end
