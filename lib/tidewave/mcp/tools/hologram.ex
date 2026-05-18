defmodule Tidewave.MCP.Tools.Hologram do
  @moduledoc false

  alias Tidewave.MCP.Tools.Source

  @default_mfa_limit 100
  @default_max_paths 5
  @reflection Hologram.Reflection
  @call_graph Hologram.Compiler.CallGraph
  @digraph Hologram.Compiler.Digraph
  @server Hologram.Server
  @compiler Hologram.Compiler
  @plt Hologram.Commons.PLT
  @ir Hologram.Compiler.IR
  @encoder Hologram.Compiler.Encoder
  @encoder_context Hologram.Compiler.Context

  def tools do
    if Code.ensure_loaded?(@reflection) do
      [
        %{
          name: "get_hologram_pages",
          description: """
          Lists all Hologram pages in the project with their route and source path.

          Use this tool to discover pages before grepping the filesystem. Pages are
          modules that `use Hologram.Page` and define a `route` macro.

          For deeper introspection of a specific page, use `project_eval` with:
          - `Hologram.Reflection.list_pages/0`
          - `MyPage.__route__/0`         # the route string
          - `MyPage.__layout_module__/0` # the layout
          - `Hologram.Reflection.source_path/1`
          """,
          inputSchema: %{type: "object", required: [], properties: %{}},
          annotations: %{readOnlyHint: true},
          callback: &get_hologram_pages/1
        },
        %{
          name: "get_hologram_components",
          description: """
          Lists all Hologram components in the project with their source path and a
          flag indicating stateful, stateless, or layout.

          Use this tool to find components before grepping. Stateless components
          cannot handle events directly — they need a parent with a `cid` to own the
          action or command.

          A component is "stateful" when it exports an `action/3` or `command/3`
          callback; "layout" when it is referenced via a page's `__layout_module__/0`;
          otherwise "stateless".

          For deeper introspection of a specific component, use `project_eval` with:
          - `MyComponent.__props__/0`      # declared props with types
          - `Hologram.Reflection.component?/1`
          - `Hologram.Reflection.source_path/1`
          """,
          inputSchema: %{type: "object", required: [], properties: %{}},
          annotations: %{readOnlyHint: true},
          callback: &get_hologram_components/1
        },
        %{
          name: "get_page_runtime_mfas",
          description: """
          For a given Hologram page, lists the MFAs that end up running in the
          browser (client) and/or on the server.

          Use this tool to:
          - Verify a function will run where you expect
          - Find oversized client dependencies pulled in unintentionally
          - Diagnose unexpected bundle growth

          Bundle byte sizes are reported when `include_sizes: true` is passed. The
          reported per-page total is incremental over the shared Hologram client
          runtime — it answers "how much does this page add?", not "how much JS does
          this page download in total?"

          Pair with `trace_client_inclusion` when you want to know *why* a specific
          MFA appears in the client bundle.
          """,
          inputSchema: %{
            type: "object",
            required: ["page"],
            properties: %{
              page: %{
                type: "string",
                description: "The page module name, e.g. \"MyApp.UserPage\""
              },
              side: %{
                type: "string",
                enum: ["client", "server", "both"],
                description: "Which side to report. Defaults to \"client\"."
              },
              limit: %{
                type: "integer",
                description:
                  "Cap on number of MFAs returned per side. Defaults to #{@default_mfa_limit}."
              },
              include_sizes: %{
                type: "boolean",
                description: """
                When true, computes the JS byte size for each MFA and reports a
                page-incremental bundle total (excludes the shared Hologram runtime).
                Defaults to false; enable when bundle-size analysis is the goal.
                Building the size index walks every module's IR, so this is the
                slower path.
                """
              }
            }
          },
          annotations: %{readOnlyHint: true},
          callback: &get_page_runtime_mfas/1
        },
        %{
          name: "trace_client_inclusion",
          description: """
          Explains why a given MFA appears in the Hologram client bundle by returning
          the shortest call paths from page entry points (`template/0`, `action/3`,
          the layout's `template/0`, plus the page's reflection MFAs) to that MFA.

          This is distinct from `mix holo.compiler.runtime_to_mfa_paths`, which
          traces from the Hologram client runtime's internal entries
          (`asset_path_registry_class`, `component_registry_class`, etc.). This tool
          traces from YOUR pages.

          For MFAs that are manually ported to JavaScript (parts of `String`,
          `IO.inspect`, `Hologram.JS.*`, etc.), the tool still returns the call paths
          and includes a note that the implementation is hand-written JS rather than
          transpiled Elixir.

          Use this tool when `get_page_runtime_mfas` shows an unexpected function in
          the client bundle and you need to find which page-side code is pulling it
          in. Common follow-ups: move the call into a Command, replace the
          dependency, or guard the call with `if Hologram.Reflection.env() == :server`.
          """,
          inputSchema: %{
            type: "object",
            required: ["mfa"],
            properties: %{
              mfa: %{
                type: "string",
                description:
                  "The MFA to trace, in the form \"Module.function/arity\", e.g. \"Decimal.round/2\"."
              },
              page: %{
                type: "string",
                description:
                  "Optional. Restrict the search to call paths originating from this page module. If omitted, searches paths from every page's entry MFAs."
              },
              max_paths: %{
                type: "integer",
                description:
                  "Maximum number of paths to return. Defaults to #{@default_max_paths}."
              }
            }
          },
          annotations: %{readOnlyHint: true},
          callback: &trace_client_inclusion/1
        },
        %{
          name: "dispatch_command",
          description: """
          Dispatches a Hologram command directly to its callback, bypassing the
          browser. The command callback runs with a `%Hologram.Server{}` struct
          seeded from the optional `session` and `cookies` args, and the resulting
          struct is returned (state transitions, cookie ops, session ops, and any
          queued next action).

          Use this tool to verify a command implementation after editing it, without
          driving the UI. The behavior matches a real command dispatch except for
          HTTP-layer concerns (CSRF, payload deserialization).

          Side effects (DB writes, process spawns, external HTTP, GenServer messages)
          run as they would in production — treat this like `execute_sql_query` and
          use test data, a temporary user, or manual cleanup when needed.

          Session note: session keys are stored as strings to match
          `Hologram.Server.get_session/3`, which coerces atom lookups to strings.
          """,
          inputSchema: %{
            type: "object",
            required: ["module", "command"],
            properties: %{
              module: %{
                type: "string",
                description:
                  "The page or stateful component module that owns the command, e.g. \"MyApp.UserPage\"."
              },
              command: %{
                type: "string",
                description: "The command name as an atom, e.g. \"save_user\"."
              },
              params: %{
                type: "object",
                description:
                  "Params map passed to the command callback. Keys are converted to atoms (only atoms that already exist). String values pass through."
              },
              session: %{
                type: "object",
                description:
                  "Optional initial session map for the Hologram.Server struct. Keys are stored as strings to match Hologram's session lookup semantics. Example: {\"user_id\": \"<uuid>\"}."
              },
              cookies: %{
                type: "object",
                description:
                  "Optional initial cookies map for the Hologram.Server struct. Keys must be strings."
              }
            }
          },
          callback: &dispatch_command/2
        }
      ]
    else
      []
    end
  end

  # --- Tool 1: get_hologram_pages -------------------------------------------

  def get_hologram_pages(_args) do
    rows =
      for module <- reflection_list_pages() do
        route = safe_route(module)
        location = source_location(module)
        "* #{route}\t#{inspect(module)}\tat #{location}"
      end

    case rows do
      [] -> {:error, "No Hologram pages found in the project"}
      rows -> {:ok, Enum.join(rows, "\n")}
    end
  end

  defp safe_route(module) do
    if function_exported?(module, :__route__, 0) do
      module.__route__()
    else
      "(no route)"
    end
  end

  # --- Tool 2: get_hologram_components --------------------------------------

  def get_hologram_components(_args) do
    layouts = layout_modules()

    rows =
      for module <- reflection_list_modules(),
          reflection_component?(module),
          not reflection_page?(module) do
        kind = component_kind(module, layouts)
        location = source_location(module)
        "* #{inspect(module)}\t(#{kind})\tat #{location}"
      end

    case rows do
      [] -> {:error, "No Hologram components found in the project"}
      rows -> {:ok, Enum.join(rows, "\n")}
    end
  end

  defp layout_modules do
    for page <- reflection_list_pages(),
        function_exported?(page, :__layout_module__, 0),
        into: MapSet.new(),
        do: page.__layout_module__()
  end

  defp component_kind(module, layouts) do
    cond do
      MapSet.member?(layouts, module) -> "layout"
      stateful?(module) -> "stateful"
      true -> "stateless"
    end
  end

  defp stateful?(module) do
    function_exported?(module, :action, 3) or function_exported?(module, :command, 3)
  end

  # --- Tool 3: get_page_runtime_mfas ----------------------------------------

  def get_page_runtime_mfas(args) do
    with {:ok, page_module} <- parse_module(args["page"]),
         :ok <- ensure_page(page_module) do
      side = args["side"] || "client"
      limit = args["limit"] || @default_mfa_limit

      if args["include_sizes"] == true do
        list_with_sizes(page_module, side, limit)
      else
        list_without_sizes(page_module, side, limit)
      end
    end
  end

  defp list_without_sizes(page_module, side, limit) do
    with {:ok, call_graph} <- load_call_graph() do
      try do
        {selected, total_count, label} =
          partition_page_mfas(call_graph, page_module, side)

        header =
          """
          Page: #{inspect(page_module)}
          Side: #{label}

          MFAs (showing #{min(total_count, limit)} of #{total_count}):
          """

        rendered =
          selected
          |> Enum.take(limit)
          |> Enum.map_join("\n", &format_mfa/1)

        {:ok, header <> rendered}
      after
        call_graph_stop(call_graph)
      end
    end
  end

  defp list_with_sizes(page_module, side, limit) do
    ir_plt = load_or_build_ir_plt()
    call_graph = build_call_graph_for_sizing(ir_plt)

    try do
      aggregated_funs = aggregate_funs(ir_plt)
      {selected, total_count, label} = partition_page_mfas(call_graph, page_module, side)

      sized =
        selected
        |> Enum.map(fn mfa -> {mfa, mfa_size(mfa, aggregated_funs)} end)
        |> Enum.sort_by(fn {_mfa, size} -> -(size || -1) end)

      total_bytes =
        sized
        |> Enum.map(fn {_mfa, size} -> size end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sum()

      header =
        """
        Page: #{inspect(page_module)}
        Side: #{label}
        Page-incremental bundle size: #{format_bytes(total_bytes)}
        (excludes shared Hologram runtime)

        MFAs (showing #{min(total_count, limit)} of #{total_count}), sorted by size descending:
        """

      rendered =
        sized
        |> Enum.take(limit)
        |> Enum.map_join("\n", &format_sized_mfa/1)

      {:ok, header <> rendered}
    after
      call_graph_stop(call_graph)
      plt_stop(ir_plt)
    end
  end

  # Returns `{selected_mfas, total_count, label}` based on `side`. Uses the
  # given call graph (full or trimmed) to compute reachability.
  #
  # Client MFAs are those reachable from `page_entry_mfas/1`
  # (template/action/reflection). For the server side we union:
  # - `list_page_mfas/2` (which adds server-init reflection reachables), and
  # - reachable from `server_entry_mfas/2` (init/3 and command/3 on the page
  #   plus on every reachable component) — this is what makes the server
  #   partition non-trivial; `list_page_mfas/2` alone only surfaces struct
  #   and schema accessors via `add_reflection_mfas_reachable_from_server_inits`.
  defp partition_page_mfas(call_graph, page_module, side) do
    graph = call_graph_get_graph(call_graph)
    page_mfas = call_graph_list_page_mfas(call_graph, page_module)

    client_mfas =
      graph
      |> digraph_reachable(page_entry_mfas(page_module))
      |> Enum.filter(&match?({_m, _f, _a}, &1))
      |> MapSet.new()

    server_mfas =
      graph
      |> digraph_reachable(server_entry_mfas(page_module, page_mfas))
      |> Enum.filter(&match?({_m, _f, _a}, &1))
      |> MapSet.new()
      |> MapSet.union(MapSet.new(page_mfas))
      |> MapSet.difference(client_mfas)

    case side do
      "server" ->
        list = server_mfas |> MapSet.to_list() |> Enum.sort()
        {list, length(list), "server"}

      "both" ->
        combined = MapSet.union(client_mfas, server_mfas)
        list = combined |> MapSet.to_list() |> Enum.sort()
        {list, length(list), "both (client + server)"}

      _ ->
        list = client_mfas |> MapSet.to_list() |> Enum.sort()
        {list, length(list), "client"}
    end
  end

  # Server-side entries: init/3 and command/3 on the page and on every component
  # whose MFAs already appear in the page's call graph. `list_page_entry_mfas/1`
  # (in older Hologram) returns only client entries; this complements it.
  defp server_entry_mfas(page_module, page_mfas) do
    components =
      page_mfas
      |> Enum.map(fn {module, _f, _a} -> module end)
      |> Enum.uniq()
      |> Enum.filter(&reflection_component?/1)

    for module <- [page_module | components],
        fun <- [:init, :command],
        function_exported?(module, fun, 3),
        do: {module, fun, 3}
  end

  defp format_mfa({mod, fun, arity}) do
    "  #{inspect(mod)}.#{fun}/#{arity}"
  end

  defp format_sized_mfa({{mod, fun, arity}, nil}) do
    suffix = if erlang_module?(mod), do: "(Erlang module)", else: "(manually ported)"
    String.pad_trailing("  #{inspect(mod)}.#{fun}/#{arity}", 56) <> "  —   " <> suffix
  end

  defp format_sized_mfa({{mod, fun, arity}, size}) do
    label = "  #{inspect(mod)}.#{fun}/#{arity}"
    String.pad_trailing(label, 56) <> "  " <> format_bytes(size)
  end

  defp format_bytes(n) when is_integer(n) do
    formatted = String.replace(Integer.to_string(n), ~r/(?<=\d)(?=(\d{3})+$)/, ",")
    formatted <> " bytes"
  end

  defp erlang_module?(module) when is_atom(module) do
    not String.starts_with?(Atom.to_string(module), "Elixir.")
  end

  # --- Sizing helpers (lifted from mix holo.compiler.page_ex_fun_sizes) -----

  defp aggregate_funs(ir_plt) do
    ir_plt
    |> plt_get_all()
    |> Enum.reduce(%{}, fn {module, module_def_ir}, acc ->
      module_def_ir
      |> ir_aggregate_module_funs()
      |> Enum.reduce(acc, fn {{function, arity}, fun_data}, module_acc ->
        Map.put(module_acc, {module, function, arity}, fun_data)
      end)
    end)
  end

  defp mfa_size({module, fun, arity} = mfa, aggregated_funs) do
    case aggregated_funs[mfa] do
      {visibility, clauses} ->
        module_name = reflection_module_name(module)

        module_name
        |> encoder_encode_elixir_function(fun, arity, visibility, clauses, encoder_context())
        |> String.length()

      _ ->
        nil
    end
  end

  defp load_or_build_ir_plt do
    dump_path = Path.join(reflection_build_dir(), reflection_ir_plt_dump_file_name())
    plt = plt_start()

    if File.exists?(dump_path) do
      plt_load(plt, dump_path)
    else
      # Fall back to a full build if the project hasn't been compiled with
      # Hologram yet. This walks every module in the project and is the slow
      # path the `include_sizes` opt-in is meant to gate.
      built = compiler_build_ir_plt()

      built
      |> plt_get_all()
      |> Enum.each(fn {k, v} -> plt_put(plt, k, v) end)

      plt_stop(built)
    end

    plt
  end

  # Sizing call graph: drop manually-ported and runtime MFAs so totals reflect
  # what THIS page adds beyond the shared Hologram client runtime.
  defp build_call_graph_for_sizing(ir_plt) do
    call_graph = compiler_build_call_graph(ir_plt)
    call_graph_remove_manually_ported(call_graph)
    runtime_mfas = call_graph_list_runtime_mfas(call_graph)
    call_graph_remove_runtime_mfas!(call_graph, runtime_mfas)
    call_graph
  end

  # Page entry MFAs: the functions Hologram invokes directly on a page (and its
  # layout) to render. Anything reachable from this set in the call graph is
  # client-side code. Equivalent to `CallGraph.list_page_entry_mfas/1` in older
  # Hologram versions; inlined here so we don't depend on its availability.
  defp page_entry_mfas(page_module) do
    layout_module =
      if function_exported?(page_module, :__layout_module__, 0) do
        page_module.__layout_module__()
      end

    page_entries = [
      {page_module, :__layout_module__, 0},
      {page_module, :__layout_props__, 0},
      {page_module, :__params__, 0},
      {page_module, :__route__, 0},
      {page_module, :action, 3},
      {page_module, :template, 0}
    ]

    layout_entries =
      if layout_module do
        [
          {layout_module, :__props__, 0},
          {layout_module, :action, 3},
          {layout_module, :template, 0}
        ]
      else
        []
      end

    page_entries ++ layout_entries
  end

  # --- Tool 4: trace_client_inclusion ---------------------------------------

  def trace_client_inclusion(args) do
    with {:ok, dest_mfa} <- parse_mfa(args["mfa"]),
         {:ok, page_filter} <- parse_optional_module(args["page"]),
         {:ok, call_graph} <- load_call_graph() do
      max_paths = args["max_paths"] || @default_max_paths

      try do
        format_trace(call_graph, dest_mfa, page_filter, max_paths)
      after
        call_graph_stop(call_graph)
      end
    end
  end

  defp format_trace(call_graph, dest_mfa, page_filter, max_paths) do
    graph = call_graph_get_graph(call_graph)

    entries =
      case page_filter do
        nil ->
          reflection_list_pages()
          |> Enum.flat_map(&page_entry_mfas/1)
          |> Enum.uniq()

        page ->
          page_entry_mfas(page)
      end

    paths =
      entries
      |> Enum.map(fn entry ->
        {entry, digraph_shortest_path(graph, entry, dest_mfa)}
      end)
      |> Enum.filter(fn {_entry, path} -> is_list(path) and path != [] end)
      |> Enum.sort_by(fn {_entry, path} -> length(path) end)
      |> Enum.take(max_paths)

    case paths do
      [] ->
        scope =
          case page_filter do
            nil -> "any page entry point"
            page -> inspect(page)
          end

        {:ok, "No call path found from #{scope} to #{format_vertex(dest_mfa)}."}

      paths ->
        prefix = manually_ported_prefix(dest_mfa)
        header = "Tracing #{format_vertex(dest_mfa)} in the client runtime.\n"

        rendered =
          paths
          |> Enum.with_index(1)
          |> Enum.map_join("\n\n", fn {{entry, path}, idx} ->
            "Path #{idx} (from #{format_vertex(entry)}, #{length(path) - 1} hops):\n" <>
              render_path(path)
          end)

        {:ok, prefix <> header <> "\n" <> rendered}
    end
  end

  defp manually_ported_prefix(dest_mfa) do
    if dest_mfa in call_graph_manually_ported() do
      """
      Note: #{format_vertex(dest_mfa)} is manually ported to JavaScript by Hologram.
      The path below shows which page-side code reaches the call site;
      the function body is hand-written JS, not transpiled Elixir.

      """
    else
      ""
    end
  end

  defp render_path(path) do
    path
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {vertex, idx} ->
      indent = String.duplicate("  ", idx + 1)
      arrow = if idx == 0, do: "", else: "-> "
      "#{indent}#{arrow}#{format_vertex(vertex)}"
    end)
  end

  defp format_vertex({mod, fun, arity}), do: "#{inspect(mod)}.#{fun}/#{arity}"
  defp format_vertex(module) when is_atom(module), do: inspect(module)
  defp format_vertex(other), do: inspect(other)

  # --- Tool 5: dispatch_command ---------------------------------------------

  def dispatch_command(%{"module" => mod_str, "command" => cmd_str} = args, assigns) do
    with {:ok, module} <- parse_module(mod_str),
         {:ok, command} <- parse_existing_atom(cmd_str),
         :ok <- ensure_has_command_callback(module),
         {:ok, params} <- atomize_known_keys(args["params"] || %{}) do
      session = stringify_keys(args["session"] || %{})
      cookies = args["cookies"] || %{}
      server = struct!(@server, session: session, cookies: cookies)

      try do
        format_command_result(module, command, module.command(command, params, server), assigns)
      rescue
        e in FunctionClauseError ->
          if e.module == module and e.function == :command and e.arity == 3 do
            {:error,
             "Command :#{command} is not defined as a clause of " <>
               "#{inspect(module)}.command/3"}
          else
            reraise(e, __STACKTRACE__)
          end
      end
    end
  end

  def dispatch_command(_args, _assigns) do
    {:error, "module and command are required"}
  end

  defp ensure_has_command_callback(module) do
    if function_exported?(module, :command, 3) do
      :ok
    else
      {:error, "#{inspect(module)} does not define a `command/3` callback"}
    end
  end

  defp format_command_result(module, command, result, assigns) do
    case result do
      %{__struct__: @server} = result ->
        {:ok,
         "Command #{inspect(module)}.#{command} dispatched.\n\n" <>
           inspect(result, assigns.inspect_opts)}

      other ->
        {:error, "Unexpected return value from command: #{inspect(other, assigns.inspect_opts)}"}
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end

  defp atomize_known_keys(map) when is_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case key_to_existing_atom(k) do
        {:ok, key} -> {:cont, {:ok, Map.put(acc, key, v)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp key_to_existing_atom(atom) when is_atom(atom), do: {:ok, atom}

  defp key_to_existing_atom(str) when is_binary(str) do
    {:ok, String.to_existing_atom(str)}
  rescue
    ArgumentError ->
      {:error, "params key #{inspect(str)} is not an existing atom in the project"}
  end

  # --- Helpers --------------------------------------------------------------

  defp parse_module(nil), do: {:error, "module is required"}

  defp parse_module(str) when is_binary(str) do
    trimmed = String.trim(str)

    if trimmed =~ ~r/\A[A-Z][\w.]*\z/ do
      {:ok, Module.safe_concat([trimmed])}
    else
      {:error, "Unknown module: #{inspect(str)}"}
    end
  rescue
    ArgumentError -> {:error, "Unknown module: #{str}"}
  end

  defp parse_optional_module(nil), do: {:ok, nil}
  defp parse_optional_module(str), do: parse_module(str)

  defp parse_existing_atom(str) when is_binary(str) do
    {:ok, String.to_existing_atom(str)}
  rescue
    ArgumentError -> {:error, "Unknown atom: #{str}"}
  end

  defp parse_mfa(nil), do: {:error, "mfa is required"}

  defp parse_mfa(str) when is_binary(str) do
    case Regex.run(~r/\A(.+)\.([^.\/]+)\/(\d+)\z/, str) do
      [_, mod_str, fun_str, arity_str] ->
        with {:ok, module} <- parse_module(mod_str),
             {:ok, fun} <- parse_existing_atom(fun_str) do
          {:ok, {module, fun, String.to_integer(arity_str)}}
        end

      _ ->
        {:error, "Invalid MFA format: #{inspect(str)}. Expected \"Module.function/arity\"."}
    end
  end

  defp ensure_page(module) do
    if reflection_page?(module) do
      :ok
    else
      {:error, "#{inspect(module)} is not a Hologram page (no `use Hologram.Page`)."}
    end
  end

  defp load_call_graph do
    dump_path = Path.join(reflection_build_dir(), reflection_call_graph_dump_file_name())

    if File.exists?(dump_path) do
      call_graph = call_graph_start()
      call_graph_load(call_graph, dump_path)
      {:ok, call_graph}
    else
      {:error,
       "Hologram call graph not found at #{dump_path}. Run `mix compile` first to generate it."}
    end
  end

  defp source_location(module) do
    case Source.get_source_location(%{"reference" => inspect(module)}) do
      {:ok, path} -> path
      _ -> "unknown"
    end
  end

  # --- Hologram interop ----------------------------------------------------
  #
  # One thin wrapper per Hologram entry point this module touches. Each one
  # is a single `apply/3` so the host project compiles without Hologram in
  # its dep tree. Call sites use these helpers; do not call `apply/3`
  # directly elsewhere in the module.

  defp reflection_list_pages, do: apply(@reflection, :list_pages, [])
  defp reflection_list_modules, do: apply(@reflection, :list_elixir_modules, [])
  defp reflection_component?(mod), do: apply(@reflection, :component?, [mod])
  defp reflection_page?(mod), do: apply(@reflection, :page?, [mod])
  defp reflection_build_dir, do: apply(@reflection, :build_dir, [])
  defp reflection_module_name(mod), do: apply(@reflection, :module_name, [mod])

  defp reflection_call_graph_dump_file_name,
    do: apply(@reflection, :call_graph_dump_file_name, [])

  defp reflection_ir_plt_dump_file_name,
    do: apply(@reflection, :ir_plt_dump_file_name, [])

  defp call_graph_start, do: apply(@call_graph, :start, [])
  defp call_graph_stop(cg), do: apply(@call_graph, :stop, [cg])
  defp call_graph_load(cg, path), do: apply(@call_graph, :load, [cg, path])
  defp call_graph_get_graph(cg), do: apply(@call_graph, :get_graph, [cg])
  defp call_graph_list_page_mfas(cg, page), do: apply(@call_graph, :list_page_mfas, [cg, page])
  defp call_graph_list_runtime_mfas(cg), do: apply(@call_graph, :list_runtime_mfas, [cg])
  defp call_graph_manually_ported, do: apply(@call_graph, :manually_ported_elixir_mfas, [])

  defp call_graph_remove_manually_ported(cg),
    do: apply(@call_graph, :remove_manually_ported_mfas, [cg])

  defp call_graph_remove_runtime_mfas!(cg, mfas),
    do: apply(@call_graph, :remove_runtime_mfas!, [cg, mfas])

  defp digraph_reachable(graph, vs), do: apply(@digraph, :reachable, [graph, vs])

  defp digraph_shortest_path(graph, from, to),
    do: apply(@digraph, :shortest_path, [graph, from, to])

  defp plt_start, do: apply(@plt, :start, [])
  defp plt_stop(plt), do: apply(@plt, :stop, [plt])
  defp plt_load(plt, path), do: apply(@plt, :load, [plt, path])
  defp plt_put(plt, k, v), do: apply(@plt, :put, [plt, k, v])
  defp plt_get_all(plt), do: apply(@plt, :get_all, [plt])

  defp compiler_build_ir_plt, do: apply(@compiler, :build_ir_plt, [])
  defp compiler_build_call_graph(plt), do: apply(@compiler, :build_call_graph, [plt])

  defp ir_aggregate_module_funs(ir), do: apply(@ir, :aggregate_module_funs, [ir])

  defp encoder_encode_elixir_function(mod_name, fun, arity, vis, clauses, ctx) do
    apply(@encoder, :encode_elixir_function, [mod_name, fun, arity, vis, clauses, ctx])
  end

  defp encoder_context, do: struct!(@encoder_context, [])
end
