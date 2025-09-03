defmodule Tidewave do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts) do
    external_tools = Keyword.get(opts, :external_tools, nil)
    init_external_tools(external_tools)

    %{
      allowed_origins: Keyword.get(opts, :allowed_origins, nil),
      allow_remote_access: Keyword.get(opts, :allow_remote_access, false),
      external_tools: external_tools,
      phoenix_endpoint: nil,
      inspect_opts:
        Keyword.get(opts, :inspect_opts, charlists: :as_lists, limit: 50, pretty: true)
    }
  end

  @impl true
  def call(%Plug.Conn{path_info: ["tidewave" | rest]} = conn, config) do
    config = %{config | phoenix_endpoint: conn.private[:phoenix_endpoint]}

    conn
    |> validate!()
    |> Plug.Conn.put_private(:tidewave_config, config)
    |> Plug.forward(rest, Tidewave.Router, [])
    |> Plug.Conn.halt()
  end

  def call(conn, _opts), do: validate!(conn)

  defp validate!(conn) do
    if live_reload_enabled?(conn) or request_body_parsed?(conn) do
      raise "plug Tidewave is runnning too late, after the request body has been parsed. " <>
              "Make sure to place \"plug Tidewave\" before the \"if code_reloading? do\" block"
    end

    conn
  end

  defp live_reload_enabled?(conn) do
    match?(%{phoenix_live_reload: true}, conn.private)
  end

  defp request_body_parsed?(conn) do
    not match?(%Plug.Conn.Unfetched{}, conn.body_params)
  end

  defp init_external_tools(nil), do: :ok

  defp init_external_tools(module_names) do
    new_tools =
      module_names
      |> Enum.uniq()
      |> Enum.flat_map(& &1.tools())

    dispatch_map =
      Map.new(new_tools, &{&1.name, &1.callback})

    add_tools(new_tools, dispatch_map)
  end

  defp add_tools(new_tools, dispatch_map) do
    {old_tools, old_dispatch_map} =
      case :ets.lookup(:tidewave_tools, :tools) do
        [{:tools, {tools, dmap}}] -> {tools, dmap}
        [] -> {[], %{}}
      end

    new_tools = Enum.reject(new_tools, &(&1 in old_tools))
    updated_tools = old_tools ++ new_tools
    updated_dispatch_map = Map.merge(old_dispatch_map, dispatch_map)

    :ets.insert(:tidewave_tools, {:tools, {updated_tools, updated_dispatch_map}})
  end
end
