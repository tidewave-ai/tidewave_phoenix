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
        Returns the location of dependency packages.

        You can use this tool to get the location of any project dependency. Optionally,
        a specific dependency name can be provided to only return the location of that dependency.

        Packages that are placed with the current project will return
        a relative path and can be read as part of the project files.
        Dependencies with an absolute path must be read with care
        through shell commands.
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
        {:ok, Path.relative_to(all_deps[package], MCP.root())}

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

  defp find_source_for_mfa(mod, function, arity, fuzzy? \\ true) do
    result = open_mfa(mod, function, arity)

    case result do
      {_source_file, _module_pair, {fun_file, fun_line}} ->
        {:ok, "#{Path.relative_to(fun_file, MCP.root())}:#{fun_line}"}

      {_source_file, {module_file, module_line}, nil} when is_nil(function) ->
        {:ok, "#{Path.relative_to(module_file, MCP.root())}:#{module_line}"}

      {source_file, nil, nil} when is_nil(function) ->
        {:ok, Path.relative_to(source_file, MCP.root())}

      {:error, :core_library} ->
        {:error,
         "Cannot get source of core libraries, use the eval_project tool with the `h(...)` helper to read documentation instead."}

      _ ->
        if fuzzy? do
          fuzzy_find_source_for_mfa(mod, function, arity)
        else
          {:error, "Failed to get source location. No candidates found."}
        end
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
        {:error, :core_library}

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

  defp fuzzy_find_source_for_mfa(mod, function, arity, type \\ :project) do
    modules =
      case type do
        :project -> project_modules()
        _ -> all_modules()
      end

    candidates =
      for candidate <- modules,
          distance = alias_aware_distance(mod, candidate),
          distance > 0.8,
          do: {distance, candidate}

    candidates =
      candidates
      |> Enum.sort_by(fn {distance, _} -> distance end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {_, candidate} -> candidate end)

    try_find_and_halt = fn mod, fun, arity, acc ->
      with :error <- okay_if_only_searching_module(mod, fun),
           :error <- find_same_function_different_arity(mod, fun, arity),
           :error <- find_similar_function(mod, fun, arity) do
        {:cont, acc}
      else
        {:ok, result} -> {:halt, {:ok, result}}
      end
    end

    result =
      Enum.reduce_while(
        candidates,
        {:error, "Failed to get source location. No candidates found."},
        fn candidate, acc ->
          try_find_and_halt.(candidate, function, arity, acc)
        end
      )

    case result do
      {:ok, {new_mod, new_fun, new_arity}} ->
        {:error,
         "Did not find exact match. Did you mean: #{format_mfa(new_mod, new_fun, new_arity)}"}

      {:error, error} ->
        if type == :project do
          # try looking into dependencies as well
          fuzzy_find_source_for_mfa(mod, function, arity, :all)
        else
          {:error, error}
        end
    end
  end

  defp project_modules do
    otp_app = Mix.Project.config()[:app]
    Application.spec(otp_app, :modules)
  end

  defp all_modules do
    for {app, _, _} <- Application.loaded_applications(),
        # exclude core apps
        app not in @apps,
        mod <- Application.spec(app, :modules),
        do: mod
  end

  defp alias_aware_distance(search, candidate) do
    search = inspect(search)
    candidate = inspect(candidate)
    search_parts = String.split(search, ".")
    search_parts_count = Enum.count(search_parts)
    candidate_parts = String.split(candidate, ".")
    candidate_parts_count = Enum.count(candidate_parts)

    # we get the suffix of the candidate that matches the length of the search;
    # for example if someone searches for User.Token, we consider
    # MyApp.Accounts.User.Token as a good match
    candidate_suffix =
      candidate_parts
      |> Enum.reverse()
      |> Enum.take(search_parts_count)
      |> Enum.reverse()
      |> Enum.join(".")

    jaro_score = String.jaro_distance(search, candidate_suffix)
    length_diff = abs(candidate_parts_count - search_parts_count)

    # apply a penalty for longer module paths
    # to make shorter matches preferred when Jaro scores are equal
    length_penalty = 1 / (1 + length_diff)
    jaro_score * (0.9 + 0.1 * length_penalty)
  end


  defp all_functions(module) do
    with [_ | _] = beam <- :code.which(module),
         {:ok, {_, [abstract_code: abstract_code]}} <- :beam_lib.chunks(beam, [:abstract_code]),
         {:raw_abstract_v1, code} <- abstract_code do
      for {:function, _ann, ann_fun, ann_arity, _} <- code do
        {ann_fun, ann_arity}
      end
    else
      _ -> []
    end
  end

  defp okay_if_only_searching_module(mod, nil) do
    {:ok, {mod, nil, :*}}
  end

  defp okay_if_only_searching_module(_mod, _), do: :error

  defp find_same_function_different_arity(_mod, _fun, :*), do: :error

  defp find_same_function_different_arity(mod, fun, _arity) do
    functions = all_functions(mod)

    if {fun, arity} = Enum.find(functions, fn {candidate_fun, _} -> candidate_fun == fun end) do
      {:ok, {mod, fun, arity}}
    else
      :error
    end
  end

  defp find_similar_function(mod, fun, arity) do
    functions = all_functions(mod)

    mapper =
      case arity do
        :* -> fn fun, _arity -> "#{fun}" end
        _ -> fn fun, arity -> "#{fun}/#{arity}" end
      end

    candidates =
      for {candidate_fun, candidate_arity} <- functions,
          distance =
            String.jaro_distance(mapper.(fun, arity), mapper.(candidate_fun, candidate_arity)) >
              0.8,
          do: {distance, {candidate_fun, candidate_arity}}

    case candidates
         |> Enum.sort_by(fn {distance, _} -> distance end, :desc)
         |> Enum.take(1)
         |> Enum.map(fn {_, candidate} -> candidate end) do
      [{fun, arity}] ->
        {:ok, {mod, fun, arity}}

      _ ->
        :error
    end
  end

  defp format_mfa(mod, nil, _), do: inspect(mod)
  defp format_mfa(mod, fun, :*), do: "#{inspect(mod)}.#{fun}"
  defp format_mfa(mod, fun, arity), do: "#{inspect(mod)}.#{fun}/#{arity}"
end
