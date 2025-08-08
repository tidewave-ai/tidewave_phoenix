defmodule Tidewave do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      allowed_origins: Keyword.get(opts, :allowed_origins, nil),
      sse_keepalive_timeout: Keyword.get(opts, :sse_keepalive_timeout, 15_000),
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
    |> Plug.Conn.put_private(:tidewave_config, config)
    |> Plug.forward(rest, Tidewave.Router, [])
    |> Plug.Conn.halt()
  end

  def call(conn, _opts), do: conn
end
