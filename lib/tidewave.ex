defmodule Tidewave do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      allowed_origins: Keyword.get(opts, :allowed_origins, nil),
      allow_remote_access: Keyword.get(opts, :allow_remote_access, false),
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
end
