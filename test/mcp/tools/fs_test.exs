defmodule Tidewave.MCP.Tools.FSTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.FS

  describe "tools/0" do
    test "returns list of available tools" do
      tools = FS.tools()

      # Should always have these base tools
      assert Enum.any?(tools, &(&1.name == "list_project_files"))
      assert Enum.any?(tools, &(&1.name == "read_project_file"))
      assert Enum.any?(tools, &(&1.name == "write_project_file"))

      # grep tool might be available depending on the system
      has_grep = System.find_executable("rg") != nil || System.find_executable("grep") != nil

      if has_grep do
        assert Enum.any?(tools, &(&1.name == "grep_project_files"))
      else
        refute Enum.any?(tools, &(&1.name == "grep_project_files"))
      end
    end
  end

  describe "list_project_files/0" do
    test "returns a formatted list of project files" do
      assert {:ok, text} = FS.list_project_files(%{})

      assert text =~ "mix.exs\n"
      assert text =~ "README.md\n"
      assert text =~ "lib/tidewave/mcp/tools/fs.ex\n"
    end
  end

  describe "read_project_file/1" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      test_file_path = Path.join(tmp_dir, "test_read_file.txt")
      test_content = "Test content for read operation"

      File.write!(test_file_path, test_content)

      on_exit(fn -> File.rm(test_file_path) end)

      %{path: test_file_path, content: test_content}
    end

    test "successfully reads an existing file", %{path: path, content: content} do
      assert {:ok, ^content, new_state, metadata} =
               FS.read_project_file(%{"path" => path}, %{})

      assert %{read_timestamps: %{^path => _}} = new_state
      assert %{mtime: _} = metadata
    end

    test "returns error for non-existent file" do
      {:error, message} =
        FS.read_project_file(%{"path" => "nonexistent_file.txt"}, %{})

      assert message =~ "File does not exist"
    end

    test "fails for file outside project" do
      {:error, message} =
        FS.read_project_file(%{"path" => "../../README.md"}, %{})

      assert message =~ "invalid or not relative to the project root"
    end

    test "truncates long lines", %{tmp_dir: tmp_dir} do
      content = String.duplicate("a", 2100) <> "\n" <> String.duplicate("b", 2100)
      file_path = Path.join(tmp_dir, "long_line_file.txt")
      File.write!(file_path, content)

      on_exit(fn -> File.rm(file_path) end)

      assert {:ok, truncated_content, _state, _metadata} =
               FS.read_project_file(%{"path" => file_path}, %{})

      assert truncated_content =~ "a [100 characters truncated] ..."
      assert truncated_content =~ "b [100 characters truncated] ..."
    end

    test "does not truncate if raw is set", %{tmp_dir: tmp_dir} do
      content = String.duplicate("a", 2100) <> "\n" <> String.duplicate("b", 2100)
      file_path = Path.join(tmp_dir, "long_line_file.txt")
      File.write!(file_path, content)

      on_exit(fn -> File.rm(file_path) end)

      assert {:ok, read_content, _state, _metadata} =
               FS.read_project_file(%{"path" => file_path, "raw" => true}, %{})

      refute read_content =~ "a [100 characters truncated] ..."
      refute read_content =~ "b [100 characters truncated] ..."
      assert length(:binary.matches(read_content, ["a", "b"])) == 4200
    end

    test "can read from line_offset and limit to count", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "offset_test.txt")
      content = Enum.map_join(1..1000, "\n", &to_string/1) <> "\nmore content\n"
      File.write!(file_path, content)

      assert {:ok, "1\n2\n3\n4\n5\n6", _state, _metadata} =
               FS.read_project_file(%{"path" => file_path, "count" => 6}, %{})

      assert {:ok, "501\n502\n503\n504\n505", _state, _metadata} =
               FS.read_project_file(
                 %{"path" => file_path, "line_offset" => 500, "count" => 5},
                 %{}
               )

      assert {:ok, "991\n992\n993\n994\n995\n996\n997\n998\n999\n1000\nmore content\n", _state,
              _metadata} =
               FS.read_project_file(%{"path" => file_path, "line_offset" => 990}, %{})
    end
  end

  describe "write_project_file/3" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      tmp_dir = Path.relative_to_cwd(tmp_dir)
      test_file_path = Path.join(tmp_dir, "test_write_file.txt")
      test_content = "Test content for write operation"

      on_exit(fn -> File.rm(test_file_path) end)

      %{path: test_file_path, content: test_content}
    end

    test "successfully writes to a file", %{path: path, content: content} do
      assert {:ok, "Success!", %{read_timestamps: %{^path => _}}, %{mtime: _}} =
               FS.write_project_file(%{"path" => path, "content" => content}, %{})

      assert File.read!(path) == content
    end

    test "fails when file was modified since last read", %{path: path, content: content} do
      File.write!(path, "Modified content")

      assert {:error, message} =
               FS.write_project_file(
                 %{"path" => path, "content" => content},
                 %{read_timestamps: %{path => 0}}
               )

      assert message =~ "File has been modified since last read"
    end

    test "prefers given atime", %{path: path, content: content} do
      File.write!(path, "Modified content")
      stat = File.stat!(path, time: :posix)

      assert {:ok, "Success!", %{read_timestamps: %{^path => _}}, %{mtime: new_mtime}} =
               FS.write_project_file(
                 %{"path" => path, "content" => content, "atime" => stat.mtime},
                 %{}
               )

      stat = File.stat!(path, time: :posix)
      assert new_mtime == stat.mtime
    end

    test "fails when file was not read yet", %{path: path, content: content} do
      File.write!(path, "Modified content")

      {:error, message} =
        FS.write_project_file(%{"path" => path, "content" => content}, %{})

      assert message =~ "File has not been read yet"
    end

    test "creates directories if needed", %{tmp_dir: tmp_dir} do
      dir_path = Path.join(tmp_dir, "test_dir")
      file_path = Path.join(dir_path, "test_file.txt")
      content = "Test content in created directory"

      on_exit(fn ->
        File.rm(file_path)
        File.rmdir(dir_path)
      end)

      path = Path.relative_to_cwd(file_path)

      assert {:ok, _result, %{read_timestamps: %{^path => _}}, _metadata} =
               FS.write_project_file(%{"path" => file_path, "content" => content}, %{})

      assert File.exists?(file_path)
      assert File.read!(file_path) == content
    end

    test "fails if file is outside of project", %{content: content} do
      assert {:error, message} =
               FS.write_project_file(
                 %{"path" => "../../README.md", "content" => content},
                 %{}
               )

      assert message =~ "invalid or not relative to the project root"
    end

    test "automatically formats Elixir files", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_file.ex") |> Path.relative_to_cwd()

      content = """
       defmodule Foo do
          def bar do
               "Hello, world!"
         end
      end
      """

      assert {:ok, "Success!", %{read_timestamps: %{^file_path => _}}, %{mtime: _}} =
               FS.write_project_file(%{"path" => file_path, "content" => content}, %{})

      assert File.read!(file_path) == """
             defmodule Foo do
               def bar do
                 "Hello, world!"
               end
             end
             """

      File.rm!(file_path)

      assert {:error, error} =
               FS.write_project_file(%{"path" => file_path, "content" => "invalid%"}, %{})

      assert error =~ "Failed to format file"
      assert error =~ "TokenMissingError"
    end

    test "does not autoformat files when autoformat is disabled", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_file.ex") |> Path.relative_to_cwd()

      content = """
       defmodule Foo do
          def bar do
               "Hello, world!"
         end
      end
      """

      assert {:ok, "Success!", %{read_timestamps: %{^file_path => _}}, %{mtime: _}} =
               FS.write_project_file(%{"path" => file_path, "content" => content}, %{
                 autoformat: false
               })

      assert File.read!(file_path) == content
    end

    test "writes with crlf line endings if default line endings are crlf", %{path: path} do
      content = "Hello\nWorld"

      assert {:ok, "Success!", %{read_timestamps: %{^path => _}}, %{mtime: _}} =
               FS.write_project_file(%{"path" => path, "content" => content}, %{
                 default_line_endings: :crlf
               })

      written_content = File.read!(path)
      assert written_content != content
      assert String.replace(written_content, "\r\n", "\n") == content
    end

    test "detects repo line endings if default line endings are not set", %{path: path} do
      content = "Hello\nWorld"

      # this repo uses LF
      assert {:ok, "Success!", %{read_timestamps: %{^path => _}, default_line_endings: :lf},
              _metadata} =
               FS.write_project_file(%{"path" => path, "content" => content}, %{})

      assert File.read!(path) == content
    end
  end

  describe "edit_project_file/3" do
    setup do
      test_file_path = "test_read_edit.txt"
      on_exit(fn -> File.rm(test_file_path) end)

      %{path: test_file_path}
    end

    test "successfully edits a file", %{path: path} do
      test_content = """
      defmodule Foo do
        def bar do
          "Hello, world!"
        end
      end
      """

      File.write!(path, test_content)

      old_string = """
        def bar do
          "Hello, world!"
        end
      """

      new_string = """
        def bar(name) do
          "Hello, \#{name}!"
        end
      """

      assert {:ok, "Success!", %{read_timestamps: %{^path => _}}, %{mtime: _}} =
               FS.edit_project_file(
                 %{"path" => path, "old_string" => old_string, "new_string" => new_string},
                 %{read_timestamps: %{path => File.stat!(path).mtime}}
               )

      assert File.read!(path) =~ "bar(name)"
    end

    test "fails when file was modified since last read", %{path: path} do
      File.write!(path, "Modified content")

      assert {:error, message} =
               FS.edit_project_file(
                 %{"path" => path, "old_string" => "foo", "new_string" => "bar"},
                 %{read_timestamps: %{path => 0}}
               )

      assert message =~ "File has been modified since last read"
    end

    test "prefers given atime", %{path: path} do
      File.write!(path, "Modified content")
      stat = File.stat!(path, time: :posix)

      assert {:ok, "Success!", %{read_timestamps: %{^path => _}}, %{mtime: new_mtime}} =
               FS.edit_project_file(
                 %{
                   "path" => path,
                   "old_string" => "Modified",
                   "new_string" => "New",
                   "atime" => stat.mtime
                 },
                 %{read_timestamps: %{}}
               )

      stat = File.stat!(path, time: :posix)
      assert new_mtime == stat.mtime
    end

    test "fails when patch cannot be applied", %{path: path} do
      test_content = """
      defmodule Foo do
        def bar do
          "Hello, world!"
        end
      end
      """

      File.write!(path, test_content)

      old_string = "i do not exist"

      new_string = """
        def bar(name) do
          "Hello, \#{name}!"
        end
      """

      assert {:error, message} =
               FS.edit_project_file(
                 %{"path" => path, "old_string" => old_string, "new_string" => new_string},
                 %{read_timestamps: %{path => File.stat!(path).mtime}}
               )

      assert message =~
               "The original substring was not found in the file. No edits were made."
    end

    test "fails if substring is not unique", %{path: path} do
      test_content = """
      defmodule Foo do
        def foo do
          "foo bar foo"
        end
      end
      """

      File.write!(path, test_content)

      assert {:error, message} =
               FS.edit_project_file(
                 %{"path" => path, "old_string" => "foo", "new_string" => "bar"},
                 %{read_timestamps: %{path => File.stat!(path).mtime}}
               )

      assert message =~ "The substring was found more than once (3 times)"
    end

    test "fails if file is outside of project" do
      assert {:error, message} =
               FS.edit_project_file(
                 %{"path" => "../../README.md", "old_string" => "", "new_string" => ""},
                 %{}
               )

      assert message =~ "invalid or not relative to the project root"
    end
  end
end
