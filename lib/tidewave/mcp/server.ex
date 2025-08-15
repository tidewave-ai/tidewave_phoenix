defmodule Tidewave.MCP.Server do
  @moduledoc false

  require Logger

  import Plug.Conn
  alias Tidewave.MCP.Tools

  @protocol_version "2025-03-06"
  @vsn Mix.Project.config()[:version]

  ## Tool management functions

  defp raw_tools do
    [
      Tools.FS.tools(),
      Tools.Logs.tools(),
      Tools.Source.tools(),
      Tools.Eval.tools(),
      Tools.Ecto.tools(),
      Tools.Phoenix.tools(),
      Tools.Hex.tools()
    ]
    |> List.flatten()
  end

  @doc false
  def init_tools do
    tools = raw_tools()
    dispatch_map = Map.new(tools, fn tool -> {tool.name, tool.callback} end)

    # TODO: switch back to persistent_term when we don't support OTP 27 any more
    # :persistent_term.put({__MODULE__, :tools_and_dispatch}, {tools, dispatch_map})
    :ets.new(:tidewave_tools, [:set, :named_table, read_concurrency: true])
    :ets.insert(:tidewave_tools, {:tools, {tools, dispatch_map}})
  end

  @doc false
  def tools_and_dispatch do
    # TODO: switch back to persistent_term when we don't support OTP 27 any more
    # :persistent_term.get({__MODULE__, :tools_and_dispatch})
    [{:tools, tools}] = :ets.lookup(:tidewave_tools, :tools)
    tools
  end

  defp tools(connect_params) do
    {tools, _} = tools_and_dispatch()

    listable? = fn
      %{listable: listable} when is_function(listable, 1) ->
        listable.(connect_params)

      _tool ->
        true
    end

    for tool <- tools, listable?.(tool) do
      tool
      |> Map.put(:description, String.trim(tool.description))
      |> Map.drop([:callback, :listable])
    end
  end

  # A callback must return either
  #
  #   * `{:ok, result}` if the callback does not receive state
  #   * `{:ok, result, new_state}` if the callback receives state (i.e. if it is of arity 2)
  #   * `{:ok, result, metadata}` if the callback is of arity 1 and returns metadata (returned as `_meta`)
  #   * `{:ok, result, new_state, metadata}` if the callback is of arity 2 and returns metadata (returned as `_meta`)
  #   * `{:error, reason}` for any error
  #   * `{:error, reason, new_state}` for any error that should also update the state
  #
  defp dispatch(name, args, assigns) do
    {_tools, dispatch} = tools_and_dispatch()

    case dispatch do
      %{^name => callback} when is_function(callback, 2) ->
        callback.(args, assigns)

      %{^name => callback} when is_function(callback, 1) ->
        callback.(args)

      _ ->
        {:error,
         %{
           code: -32601,
           message: "Method not found",
           data: %{
             name: name
           }
         }}
    end
  end

  ## MCP message processing

  defp validate_protocol_version(client_version) do
    cond do
      is_nil(client_version) ->
        {:error, "Protocol version is required"}

      client_version < unquote(@protocol_version) ->
        {:error,
         "Unsupported protocol version. Server supports #{unquote(@protocol_version)} or later"}

      true ->
        :ok
    end
  end

  defp handle_ping(request_id) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: request_id,
       result: %{}
     }}
  end

  defp handle_initialize(request_id, params, connect_params) do
    case validate_protocol_version(params["protocolVersion"]) do
      :ok ->
        {:ok,
         %{
           jsonrpc: "2.0",
           id: request_id,
           result: %{
             protocolVersion: @protocol_version,
             capabilities: %{
               tools: %{
                 listChanged: false
               }
             },
             serverInfo: %{
               name: "Tidewave MCP Server",
               version: @vsn
             },
             tools: tools(connect_params)
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_list_tools(request_id, _params, connect_params) do
    result_or_error(
      request_id,
      {:ok, %{tools: tools(connect_params)}}
    )
  end

  defp result_or_error(request_id, {:ok, text, metadata})
       when is_binary(text) and is_map(metadata) do
    result_or_error(request_id, {:ok, %{content: [%{type: "text", text: text}], _meta: metadata}})
  end

  defp result_or_error(request_id, {:ok, text}) when is_binary(text) do
    result_or_error(request_id, {:ok, %{content: [%{type: "text", text: text}]}})
  end

  defp result_or_error(request_id, {:ok, result}) when is_map(result) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: request_id,
       result: result
     }}
  end

  defp result_or_error(request_id, {:error, :invalid_arguments}) do
    {:error,
     %{
       jsonrpc: "2.0",
       id: request_id,
       error: %{code: -32602, message: "Invalid arguments for tool"}
     }}
  end

  defp result_or_error(request_id, {:error, message}) when is_binary(message) do
    # tool errors should be treated as successful response with isError: true
    # https://spec.modelcontextprotocol.io/specification/2024-11-05/server/tools/#error-handling
    result_or_error(
      request_id,
      {:ok, %{content: [%{type: "text", text: message}], isError: true}}
    )
  end

  defp result_or_error(request_id, {:error, error}) when is_map(error) do
    {:error,
     %{
       jsonrpc: "2.0",
       id: request_id,
       error: error
     }}
  end

  defp handle_call_tool(request_id, %{"name" => name} = params, assigns) do
    args = Map.get(params, "arguments", %{})
    result_or_error(request_id, dispatch(name, args, assigns))
  end

  defp safe_call_tool(request_id, params, assigns) do
    handle_call_tool(request_id, params, assigns)
  catch
    kind, reason ->
      # tool exceptions should be treated as successful response with isError: true
      # https://spec.modelcontextprotocol.io/specification/2024-11-05/server/tools/#error-handling
      {:ok,
       %{
         jsonrpc: "2.0",
         id: request_id,
         result: %{
           content: [
             %{
               type: "text",
               text: "Failed to call tool: #{Exception.format(kind, reason, __STACKTRACE__)}"
             }
           ],
           isError: true
         }
       }}
  end

  # Built-in message routing
  defp handle_message(%{"method" => "notifications/initialized"} = message, _assigns) do
    Logger.info("Received initialized notification")
    Logger.debug("Full message: #{inspect(message, pretty: true)}")
    {:ok, nil}
  end

  defp handle_message(%{"method" => "notifications/cancelled"} = message, _assigns) do
    Logger.info("Request cancelled: #{inspect(message["params"])}")
    {:ok, nil}
  end

  defp handle_message(%{"method" => method, "id" => id} = message, assigns) do
    connect_params = assigns.connect_params
    Logger.info("Routing MCP message - Method: #{method}, ID: #{id}")
    Logger.debug("Full message: #{inspect(message, pretty: true)}")

    case method do
      "ping" ->
        Logger.debug("Handling ping request")
        handle_ping(id)

      "initialize" ->
        Logger.info(
          "Handling initialize request with params: #{inspect(message["params"], pretty: true)}"
        )

        handle_initialize(id, message["params"], connect_params)

      "tools/list" ->
        Logger.debug("Handling tools list request")
        handle_list_tools(id, message["params"], connect_params)

      "tools/call" ->
        Logger.debug(
          "Handling tool call request with params: #{inspect(message["params"], pretty: true)}"
        )

        safe_call_tool(id, message["params"], assigns)

      other ->
        Logger.warning("Received unsupported method: #{other}")

        {:error,
         %{
           jsonrpc: "2.0",
           id: id,
           error: %{
             code: -32601,
             message: "Method not found",
             data: %{
               name: other
             }
           }
         }}
    end
  end

  ## HTTP transport functions

  defp validate_jsonrpc_message(%{"jsonrpc" => "2.0"} = message) do
    cond do
      # Request must have method and id (string or number)
      Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        case message["id"] do
          id when is_binary(id) or is_number(id) -> {:ok, message}
          _ -> {:error, :invalid_jsonrpc}
        end

      # Notification must have method but no id
      not Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        {:ok, message}

      # reply (e.g. to ping) with ID + result
      Map.has_key?(message, "id") and Map.has_key?(message, "result") ->
        {:ok, message}

      true ->
        {:error, :invalid_jsonrpc}
    end
  end

  defp validate_jsonrpc_message(_), do: {:error, :invalid_jsonrpc}

  defp send_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end

  defp send_jsonrpc_error(conn, id, code, message, data \\ nil) do
    error = %{
      code: code,
      message: message
    }

    error = if data, do: Map.put(error, :data, data), else: error

    response = %{
      jsonrpc: "2.0",
      id: id,
      error: error
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  def handle_http_message(conn) do
    Logger.info("Received #{conn.method} message")
    params = conn.body_params
    conn = fetch_query_params(conn)
    Logger.debug("Raw params: #{inspect(params, pretty: true)}")

    case validate_jsonrpc_message(params) do
      {:ok, message} ->
        assigns = %{connect_params: conn.query_params}
        assigns = Map.merge(assigns, conn.private.tidewave_config)

        case handle_message(message, assigns) do
          {:ok, nil} ->
            # Notifications that don't return a response
            conn |> put_status(202) |> send_json(%{status: "ok"})

          {:ok, response} ->
            Logger.debug("Sending HTTP response: #{inspect(response, pretty: true)}")
            conn |> put_status(200) |> send_json(response)

          {:error, error_response} ->
            Logger.warning("Error handling message: #{inspect(error_response)}")
            conn |> put_status(400) |> send_json(error_response)
        end

      {:error, :invalid_jsonrpc} ->
        Logger.warning("Invalid JSON-RPC message format")
        send_jsonrpc_error(conn, nil, -32600, "Could not parse message")
    end
  end
end
