defmodule Tidewave.MCP.Tools.Source do
  @moduledoc false

  alias Tidewave.MCP

  def tools do
    [
      %{
        name: "get_source_location",
        description: """
        Returns the source location for the given reference.

        This works for modules in the current project, as well as dependencies,
        but not for modules included in Elixir itself.

        This tool only works if you know the `Module`, `Module.function`, or `Module.function/arity` that is being targeted.
        If that is the case, prefer this tool over grepping the file system.
        """,
        inputSchema: %{
          type: "object",
          required: ["reference"],
          properties: %{
            reference: %{
              type: "string",
              description:
                "The reference to get source location for. Can be a module name, a Module.function or Module.function/arity."
            }
          }
        },
        callback: &get_source_location/1
      },
      %{
        name: "get_package_location",
        description: """
        Returns the location of the given dependency package.

        You can use this tool to get the location of any project dependency. Optionally,
        a specific dependency name can be provided to only return the location of that dependency.

        Use the result in combination with shell tools like grep to look for specific
        code inside dependencies.
        """,
        inputSchema: %{
          type: "object",
          required: [],
          properties: %{
            package: %{
              type: "string",
              description:
                "The name of the package to get the location of. If not provided, the location of all packages will be returned."
            }
          }
        },
        callback: &get_package_location/1
      }
    ]
  end

  def get_source_location(args) do
    case args do
      %{"reference" => ref} ->
        case parse_reference(ref) do
          {:ok, mod, fun, arity} ->
            find_source_for_mfa(mod, fun, arity)

          :error ->
            {:error, "Failed to parse reference: #{inspect(ref)}"}
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  def get_package_location(args) do
    # when no package is provided, we only return top-level dependencies,
    # but if a specific package is requested, we check all dependencies
    deps =
      Mix.Project.deps_paths(depth: 1)
      |> Map.new(fn {package, path} -> {to_string(package), path} end)

    all_deps =
      Mix.Project.deps_paths()
      |> Map.new(fn {package, path} -> {to_string(package), path} end)

    case args do
      %{"package" => package} when is_map_key(all_deps, package) ->
        {:ok, all_deps[package]}

      %{"package" => package} ->
        {:error,
         "Package #{package} not found. The overall dependency path is #{Mix.Project.deps_path()}."}

      _ ->
        {:ok,
         Enum.map_join(deps, "\n", fn {package, path} ->
           "#{package}: #{Path.relative_to(path, MCP.root())}"
         end)}
    end
  end

  defp parse_reference(string) when is_binary(string) do
    case Code.string_to_quoted(string) do
      {:ok, ast} ->
        parse_reference(ast)

      {:error, _} ->
        {:error, "Failed to parse reference: #{inspect(string)}"}
    end
  end

  defp parse_reference({:/, _, [call, arity]}) when arity in 0..255,
    do: parse_call(call, arity)

  defp parse_reference(call),
    do: parse_call(call, :*)

  defp parse_call({{:., _, [mod, fun]}, _, _}, arity),
    do: parse_module(mod, fun, arity)

  defp parse_call(mod, :*),
    do: parse_module(mod, nil, :*)

  defp parse_call(_mod, _arity),
    do: :error

  defp parse_module(mod, fun, arity) when is_atom(mod),
    do: {:ok, mod, fun, arity}

  defp parse_module({:__aliases__, _, [head | _] = parts}, fun, arity) when is_atom(head),
    do: {:ok, Module.concat(parts), fun, arity}

  defp parse_module(_mod, _fun, _arity),
    do: :error

  defp find_source_for_mfa(mod, function, arity) do
    result = open_mfa(mod, function, arity)

    case result do
      {_source_file, _module_pair, {fun_file, fun_line}} ->
        {:ok, "#{fun_file}:#{fun_line}"}

      {_source_file, {module_file, module_line}, nil} ->
        {:ok, "#{module_file}:#{module_line}"}

      {source_file, nil, nil} ->
        {:ok, source_file}

      {:error, error} ->
        {:error, "Failed to get source location: #{inspect(error)}"}
    end
  end

  # open helpers, extracted from IEx.Introspection
  defp open_mfa(module, fun, arity) do
    case Code.ensure_loaded(module) do
      {:module, _} ->
        case module.module_info(:compile)[:source] do
          [_ | _] = source ->
            with {:ok, source} <- rewrite_source(module, source) do
              open_abstract_code(module, fun, arity, source)
            end

          _ ->
            {:error, "source code is not available"}
        end

      _ ->
        {:error, "module is not available"}
    end
  end

  defp open_abstract_code(module, fun, arity, source) do
    fun = Atom.to_string(fun)

    with [_ | _] = beam <- :code.which(module),
         {:ok, {_, [abstract_code: abstract_code]}} <- :beam_lib.chunks(beam, [:abstract_code]),
         {:raw_abstract_v1, code} <- abstract_code do
      {_, module_pair, fa_pair} =
        Enum.reduce(code, {source, nil, nil}, &open_abstract_code_reduce(&1, &2, fun, arity))

      {source, module_pair, fa_pair}
    else
      _ ->
        {source, nil, nil}
    end
  end

  defp open_abstract_code_reduce(entry, {file, module_pair, fa_pair}, fun, arity) do
    case entry do
      {:attribute, ann, :module, _} ->
        {file, {file, :erl_anno.line(ann)}, fa_pair}

      {:function, ann, ann_fun, ann_arity, _} ->
        case Atom.to_string(ann_fun) do
          "MACRO-" <> ^fun when arity == :* or ann_arity == arity + 1 ->
            {file, module_pair, fa_pair || {file, :erl_anno.line(ann)}}

          ^fun when arity == :* or ann_arity == arity ->
            {file, module_pair, fa_pair || {file, :erl_anno.line(ann)}}

          _ ->
            {file, module_pair, fa_pair}
        end

      _ ->
        {file, module_pair, fa_pair}
    end
  end

  @elixir_apps ~w(eex elixir ex_unit iex logger mix)a
  @otp_apps ~w(kernel stdlib)a
  @apps @elixir_apps ++ @otp_apps

  defp rewrite_source(module, source) do
    case :application.get_application(module) do
      {:ok, app} when app in @apps ->
        {:error,
         "Cannot get source of core libraries, use the eval_project tool with the `h(...)` helper to read documentation instead."}

      _ ->
        beam_path = :code.which(module)

        if is_list(beam_path) and List.starts_with?(beam_path, :code.root_dir()) do
          app_vsn = beam_path |> Path.dirname() |> Path.dirname() |> Path.basename()
          {:ok, Path.join([:code.root_dir(), "lib", app_vsn, rewrite_source(source)])}
        else
          {:ok, List.to_string(source)}
        end
    end
  end

  defp rewrite_source(source) do
    {in_app, [lib_or_src | _]} =
      source
      |> Path.split()
      |> Enum.reverse()
      |> Enum.split_while(&(&1 not in ["lib", "src"]))

    Path.join([lib_or_src | Enum.reverse(in_app)])
  end
end
