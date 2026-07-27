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

        You can also use "dep:PACKAGE_NAME" to get the location of a specific dependency package.

        Fuzzy search: If an exact match is not found, the tool will suggest similar matches.
        You can use partial names like "User.Token" to find "MyApp.Accounts.User.Token",
        or slightly misspelled function names like "iniz" to find "init".
        """,
        inputSchema: %{
          type: "object",
          required: ["reference"],
          properties: %{
            reference: %{
              type: "string",
              description:
                "The reference to get source location for. Can be a module name (e.g., 'User'), a Module.function (e.g., 'User.changeset'), or Module.function/arity (e.g., 'User.changeset/2'). Supports fuzzy matching for partial or slightly misspelled names."
            }
          }
        },
        annotations: %{readOnlyHint: true},
        callback: &get_source_location/1
      },
      %{
        name: "get_docs",
        description: """
        Returns the documentation for the given reference.

        This works for modules and functions in the current project, as well as dependencies.
        The reference can be a module name, a Module.function or Module.function/arity.
        You may also prepend a "c:" to the reference to get docs for a callback.
        """,
        inputSchema: %{
          type: "object",
          required: ["reference"],
          properties: %{
            reference: %{
              type: "string",
              description:
                "The reference to get documentation for. Can be a module name, a Module.function or Module.function/arity."
            }
          }
        },
        annotations: %{readOnlyHint: true},
        callback: &get_docs/1
      }
    ]
  end

  def get_source_location(args) do
    case args do
      %{"reference" => "dep:" <> package} ->
        path =
          try do
            Mix.Project.deps_paths()[String.to_existing_atom(package)]
          rescue
            _ -> nil
          end

        if path do
          {:ok, Path.relative_to(path, MCP.root())}
        else
          {:error, "Package #{package} not found."}
        end

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

  def get_docs(args) do
    case args do
      %{"reference" => ref} ->
        {ref, lookup} =
          case ref do
            "c:" <> ref -> {ref, [:callback]}
            _ -> {ref, [:function, :macro]}
          end

        case parse_reference(ref) do
          {:ok, mod, fun, arity} ->
            case Code.ensure_loaded(mod) do
              {:module, _} ->
                with {:ok, _, docs} <- find_docs_for_mfa(mod, fun, arity, lookup) do
                  {:ok, docs}
                end

              {:error, reason} ->
                {:error, "Could not load module #{inspect(mod)}, got: #{reason}"}
            end

          :error ->
            {:error, "Failed to parse reference: #{inspect(ref)}"}
        end

      _ ->
        {:error, :invalid_arguments}
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
        line =
          case find_docs_for_mfa(mod, function, arity, [:function, :macro]) do
            {:ok, line, _} when line < fun_line -> line
            _ -> fun_line
          end

        {:ok, "#{Path.relative_to(fun_file, MCP.root())}:#{line}"}

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

  # Similarity threshold for fuzzy matching (0.0 to 1.0)
  # Higher values require closer matches
  @fuzzy_threshold 0.75

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

  defp find_docs_for_mfa(mod, nil, :*, _lookup) do
    case Code.fetch_docs(mod) do
      {:docs_v1, ann, _, "text/markdown", %{"en" => content}, _, _} ->
        {:ok, :erl_anno.line(ann), "# #{inspect(mod)}\n\n#{content}"}

      {:docs_v1, _, _, _, _, _, _} ->
        {:error, "Documentation not found for #{inspect(mod)}"}

      _ ->
        {:error, "No documentation available for #{inspect(mod)}"}
    end
  end

  defp find_docs_for_mfa(mod, fun, arity, lookup) do
    mod
    |> get_function_docs(lookup)
    |> filter_function_docs(fun, arity)
    |> case do
      [] ->
        {:error, "Documentation not found for #{inspect(mod)}.#{fun}/#{arity}"}

      docs ->
        [{line, _} | _] =
          formatted_docs =
          docs
          |> Enum.map(fn {{type, fun, arity}, ann, signature, doc, metadata} ->
            {:erl_anno.line(ann),
             format_function_docs(type, mod, fun, arity, signature, doc, metadata)}
          end)
          |> Enum.sort()

        {:ok, line, Enum.map_join(formatted_docs, "\n\n", &elem(&1, 1))}
    end
  end

  defp get_function_docs(mod, kinds) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _, _, "text/markdown", _, _, docs} ->
        for {{kind, _, _}, _, _, _, _} = doc <- docs, kind in kinds, do: doc

      {:error, _} ->
        []
    end
  end

  defp filter_function_docs(docs, fun, arity) when is_integer(arity) do
    doc =
      Enum.find(docs, &match?({{_, ^fun, ^arity}, _, _, _, _}, &1)) ||
        find_doc_defaults(docs, fun, arity)

    case doc do
      {_, _, _, %{"en" => _}, _} ->
        [doc]

      _ ->
        []
    end
  end

  defp filter_function_docs(docs, fun, :*) do
    Enum.filter(docs, fn
      {{_, ^fun, _}, _, _, %{"en" => _}, _} -> true
      _ -> false
    end)
  end

  defp find_doc_defaults(docs, function, min) do
    Enum.find(docs, fn
      {{_, ^function, arity}, _, _, _, %{defaults: defaults}} when arity > min ->
        arity <= min + defaults

      _ ->
        false
    end)
  end

  defp format_function_docs(type, mod, fun, arity, signature, %{"en" => content}, _metadata) do
    prefix = if type == :callback, do: "c:", else: ""

    """
    # #{prefix}#{inspect(mod)}.#{fun}/#{arity}

    ```elixir
    #{Enum.join(signature, "\n")}
    ```

    #{content}\
    """
  end

  # Fuzzy search functionality
  defp fuzzy_find_source_for_mfa(mod, function, arity, type \\ :project) do
    modules =
      case type do
        :project -> project_modules()
        _ -> all_modules()
      end

    candidates =
      for candidate <- modules,
          distance = alias_aware_distance(mod, candidate),
          distance >= @fuzzy_threshold,
          do: {distance, candidate}

    candidates =
      candidates
      |> Enum.sort_by(fn {distance, _} -> distance end, :desc)
      |> Enum.take(5)
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
        suggestion = format_mfa(new_mod, new_fun, new_arity)

        context_hint =
          cond do
            mod == new_mod and function != nil and new_fun != nil and function != new_fun ->
              " (similar function name)"

            mod == new_mod and function != nil and new_fun != nil and function == new_fun ->
              " (different arity)"

            mod != new_mod and function == nil ->
              " (similar module name)"

            true ->
              ""
          end

        {:error, "Did not find exact match. Did you mean: #{suggestion}#{context_hint}?"}

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

  defp find_same_function_different_arity(mod, fun, requested_arity) do
    functions = all_functions(mod)

    # Find functions with the same name but different arities
    case Enum.filter(functions, fn {candidate_fun, _} -> candidate_fun == fun end) do
      [] ->
        :error

      matches ->
        # Prefer arities close to the requested one
        {closest_fun, closest_arity} =
          Enum.min_by(matches, fn {_, arity} -> abs(arity - requested_arity) end)

        {:ok, {mod, closest_fun, closest_arity}}
    end
  end

  defp find_similar_function(mod, fun, _arity) do
    functions = all_functions(mod)
    search_str = to_string(fun)

    candidates =
      for {candidate_fun, candidate_arity} <- functions,
          candidate_str = to_string(candidate_fun),
          distance = String.jaro_distance(search_str, candidate_str),
          distance >= @fuzzy_threshold,
          do: {distance, {candidate_fun, candidate_arity}}

    case candidates
         |> Enum.sort_by(fn {distance, _} -> distance end, :desc)
         |> Enum.take(1) do
      [{_, {matched_fun, matched_arity}}] ->
        {:ok, {mod, matched_fun, matched_arity}}

      _ ->
        :error
    end
  end

  defp format_mfa(mod, nil, _), do: inspect(mod)
  defp format_mfa(mod, fun, :*), do: "#{inspect(mod)}.#{fun}"
  defp format_mfa(mod, fun, arity), do: "#{inspect(mod)}.#{fun}/#{arity}"
end
