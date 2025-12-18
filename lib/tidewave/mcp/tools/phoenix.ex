defmodule Tidewave.MCP.Tools.Phoenix do
  @moduledoc false

  alias Tidewave.MCP

  def tools do
    [
      %{
        name: "get_module_functions",
        description: """
        Returns the public functions of the given module with their arities and documentation.

        This works for any module - your application code, dependencies (like Phoenix, Ecto, Jason),
        or standard library modules. Use this to understand a module's API before using it.

        For example:
        - "Jason" to see encode/decode functions
        - "Phoenix.LiveView" to see push_event, assign, stream, etc.
        - "MyApp.Accounts" to see your context's public API
        """,
        inputSchema: %{
          type: "object",
          required: ["module"],
          properties: %{
            module: %{
              type: "string",
              description: "The module name (e.g., \"Jason\", \"Phoenix.LiveView\", \"MyApp.Accounts\")"
            }
          }
        },
        callback: &get_module_functions/1
      },
      %{
        name: "get_component_info",
        description: """
        Returns detailed information about a Phoenix component including its attrs, slots, and documentation.

        This works for any component - your application components, Phoenix built-in components
        (like Phoenix.Component.form), or third-party component libraries.

        Use this to understand how to use a component correctly, including required attributes,
        their types, and available slots.
        """,
        inputSchema: %{
          type: "object",
          required: ["component"],
          properties: %{
            component: %{
              type: "string",
              description:
                "The component reference as Module.function (e.g., \"Phoenix.Component.form\", \"MyAppWeb.CoreComponents.button\")"
            }
          }
        },
        callback: &get_component_info/1
      }
    ]
  end

  # ============================================================================
  # get_module_functions
  # ============================================================================

  def get_module_functions(%{"module" => module_name}) do
    case parse_module_name(module_name) do
      {:ok, module} ->
        case Code.ensure_loaded(module) do
          {:module, _} ->
            functions =
              module.__info__(:functions)
              |> Enum.map(fn {name, arity} ->
                doc = get_function_doc(module, name, arity)
                %{name: name, arity: arity, doc: doc}
              end)
              |> Enum.sort_by(&{&1.name, &1.arity})

            format_module_functions(module_name, module, functions)

          {:error, reason} ->
            {:error, "Could not load module #{module_name}: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_module_functions(_), do: {:error, :invalid_arguments}

  defp get_function_doc(module, fun, arity) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        Enum.find_value(docs, fn
          {{:function, ^fun, ^arity}, _, _, %{"en" => doc}, _} -> doc
          _ -> nil
        end)

      _ ->
        nil
    end
  end

  # ============================================================================
  # get_component_info
  # ============================================================================

  def get_component_info(%{"component" => component_ref}) do
    case parse_component_reference(component_ref) do
      {:ok, module, function} ->
        case Code.ensure_loaded(module) do
          {:module, _} ->
            cond do
              function_exported?(module, :__components__, 0) ->
                components = module.__components__()

                case Map.get(components, function) do
                  nil ->
                    # Function exists but has no attr/slot declarations
                    if function_exported?(module, function, 1) do
                      format_component_info(module, function, %{attrs: [], slots: [], line: nil})
                    else
                      {:error, "Component #{function} not found in #{inspect(module)}"}
                    end

                  component_info ->
                    format_component_info(module, function, component_info)
                end

              function_exported?(module, function, 1) ->
                # Module doesn't use Phoenix.Component macros but function exists
                format_component_info(module, function, %{attrs: [], slots: [], line: nil})

              true ->
                {:error, "#{inspect(module)}.#{function}/1 not found"}
            end

          {:error, reason} ->
            {:error, "Could not load module: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_component_info(_), do: {:error, :invalid_arguments}

  # ============================================================================
  # Source File Helpers
  # ============================================================================

  defp parse_module_name(module_name) when is_binary(module_name) do
    case Code.string_to_quoted(module_name) do
      {:ok, {:__aliases__, _, parts}} when is_list(parts) ->
        {:ok, Module.concat(parts)}

      {:ok, atom} when is_atom(atom) ->
        {:ok, atom}

      _ ->
        {:error, "Invalid module name: #{module_name}"}
    end
  end

  defp parse_component_reference(ref) when is_binary(ref) do
    case String.split(ref, ".") |> Enum.split(-1) do
      {module_parts, [function]} when module_parts != [] ->
        module_name = Enum.join(module_parts, ".")

        case parse_module_name(module_name) do
          {:ok, module} ->
            {:ok, module, String.to_atom(function)}

          error ->
            error
        end

      _ ->
        {:error, "Invalid component reference. Expected Module.function format."}
    end
  end

  defp find_source_file(module) do
    case Code.ensure_loaded(module) do
      {:module, _} ->
        case module.module_info(:compile)[:source] do
          [_ | _] = source ->
            source_path = List.to_string(source)

            if File.exists?(source_path) do
              {:ok, source_path}
            else
              # Try to find in deps
              find_source_in_deps(module, source_path)
            end

          _ ->
            {:error, "Source not available for #{inspect(module)}"}
        end

      {:error, _} ->
        {:error, "Module #{inspect(module)} not found"}
    end
  end

  defp find_source_in_deps(module, original_source) do
    # Extract relative path from original source
    relative =
      original_source
      |> Path.split()
      |> Enum.reverse()
      |> Enum.take_while(&(&1 not in ["lib", "src"]))
      |> Enum.reverse()

    if relative != [] do
      case :application.get_application(module) do
        {:ok, app} ->
          dep_path = Path.join([MCP.root(), "deps", to_string(app), "lib" | relative])

          if File.exists?(dep_path) do
            {:ok, dep_path}
          else
            {:error, "Source file not found at #{dep_path}"}
          end

        :undefined ->
          {:error, "Could not determine application for #{inspect(module)}"}
      end
    else
      {:error, "Could not determine source path for #{inspect(module)}"}
    end
  end

  # ============================================================================
  # Output Formatting
  # ============================================================================

  defp format_module_functions(module_name, module, functions) do
    source_path =
      case module.module_info(:compile)[:source] do
        nil -> nil
        source -> source |> List.to_string() |> Path.relative_to(MCP.root())
      end

    header =
      if source_path do
        "# #{module_name}\n\nSource: #{source_path}\n"
      else
        "# #{module_name}\n"
      end

    functions_text =
      if Enum.empty?(functions) do
        "\nNo public functions found."
      else
        "\n## Public Functions\n\n" <>
          (functions
           |> Enum.map(fn f ->
             doc_info = if f.doc, do: "\n  #{truncate_doc(f.doc)}", else: ""
             "* `#{f.name}/#{f.arity}`#{doc_info}"
           end)
           |> Enum.join("\n"))
      end

    {:ok, header <> functions_text}
  end

  defp truncate_doc(doc) when is_binary(doc) do
    doc
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 120)
  end

  defp truncate_doc(_), do: ""

  defp format_component_info(module, function, info) do
    source_path =
      case module.module_info(:compile)[:source] do
        nil -> nil
        source -> source |> List.to_string() |> Path.relative_to(MCP.root())
      end

    header =
      case {source_path, info[:line]} do
        {path, line} when is_binary(path) and is_integer(line) ->
          "# #{inspect(module)}.#{function}\n\nSource: #{path}:#{line}\n"

        {path, _} when is_binary(path) ->
          "# #{inspect(module)}.#{function}\n\nSource: #{path}\n"

        _ ->
          "# #{inspect(module)}.#{function}\n"
      end

    # Get function doc from Code.fetch_docs
    func_doc = get_function_doc(module, function, 1)

    doc_text =
      if func_doc do
        "\n## Documentation\n\n#{func_doc}\n"
      else
        ""
      end

    attrs_text =
      if Enum.empty?(info.attrs) do
        "\n## Attributes\n\nNo attributes defined."
      else
        "\n## Attributes\n\n" <>
          (info.attrs
           |> Enum.sort_by(fn attr -> {!attr.required, attr.name} end)
           |> Enum.map(fn attr ->
             required = if attr.required, do: " (required)", else: ""
             default_val = Keyword.get(attr.opts || [], :default)
             default = if default_val != nil, do: ", default: #{inspect(default_val)}", else: ""
             doc = if attr.doc, do: "\n  #{attr.doc}", else: ""
             "* `#{attr.name}` : `#{format_attr_type(attr.type)}`#{required}#{default}#{doc}"
           end)
           |> Enum.join("\n"))
      end

    slots_text =
      if Enum.empty?(info.slots) do
        "\n\n## Slots\n\nNo slots defined."
      else
        "\n\n## Slots\n\n" <>
          (info.slots
           |> Enum.sort_by(fn slot -> {!slot.required, slot.name} end)
           |> Enum.map(fn slot ->
             required = if slot.required, do: " (required)", else: ""
             doc = if slot.doc, do: "\n  #{slot.doc}", else: ""
             "* `#{slot.name}`#{required}#{doc}"
           end)
           |> Enum.join("\n"))
      end

    {:ok, header <> doc_text <> attrs_text <> slots_text}
  end

  defp format_attr_type({:struct, module}), do: "%#{inspect(module)}{}"
  defp format_attr_type(type), do: inspect(type)
end
