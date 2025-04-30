defmodule Tidewave.MCP.Server do
  @moduledoc false

  require Logger

  alias Tidewave.MCP
  alias Tidewave.MCP.Connection
  alias Tidewave.MCP.Tools

  @protocol_version "2024-11-05"
  @vsn Mix.Project.config()[:version]

  @doc false
  def init_tools do
    tools = raw_tools()
    dispatch_map = Map.new(tools, fn tool -> {tool.name, tool.callback} end)

    :persistent_term.put({__MODULE__, :tools_and_dispatch}, {tools, dispatch_map})
  end

  @doc false
  def tools_and_dispatch do
    :persistent_term.get({__MODULE__, :tools_and_dispatch})
  end

  defp raw_tools do
    [
      Tools.FS.tools(),
      Tools.Logs.tools(),
      Tools.Source.tools(),
      Tools.Eval.tools(),
      Tools.Ecto.tools(),
      Tools.Process.tools(),
      Tools.Phoenix.tools(),
      Tools.Hex.tools()
    ]
    |> List.flatten()
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
  #   * `{:error, reason}` for any error
  #   * `{:error, reason, new_state}` for any error that should also update the state
  #
  defp dispatch(name, args, state_pid) do
    {_tools, dispatch} = tools_and_dispatch()

    case dispatch do
      %{^name => callback} when is_function(callback, 2) ->
        MCP.Connection.dispatch(state_pid, callback, args)

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

  def handle_ping(request_id) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: request_id,
       result: %{}
     }}
  end

  def handle_initialize(request_id, params, state_pid) do
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
             tools: tools(Connection.connect_params(state_pid))
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_list_tools(request_id, _params, state_pid) do
    result_or_error(request_id, {:ok, %{tools: tools(Connection.connect_params(state_pid))}})
  end

  def handle_call_tool(request_id, %{"name" => name, "arguments" => args}, state_pid) do
    result_or_error(request_id, dispatch(name, args, state_pid))
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

  defp validate_protocol_version(client_version) do
    cond do
      is_nil(client_version) ->
        {:error, "Protocol version is required"}

      client_version >= unquote(@protocol_version) ->
        {:error, "Unsupported protocol version. Server supports #{unquote(@protocol_version)} or later"}

      true ->
        :ok
    end
  end

  ## handle_message function for SSE plug

  # Built-in message routing
  def handle_message(%{"method" => "notifications/initialized"} = message, _state_pid) do
    Logger.info("Received initialized notification")
    Logger.debug("Full message: #{inspect(message, pretty: true)}")
    {:ok, nil}
  end

  def handle_message(%{"method" => method, "id" => id} = message, state_pid) do
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

        handle_initialize(id, message["params"], state_pid)

      "tools/list" ->
        Logger.debug("Handling tools list request")
        handle_list_tools(id, message["params"], state_pid)

      "tools/call" ->
        Logger.debug(
          "Handling tool call request with params: #{inspect(message["params"], pretty: true)}"
        )

        safe_call_tool(id, message["params"], state_pid)

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

  def handle_message(unknown_message, _state_pid) do
    Logger.error("Received invalid message format: #{inspect(unknown_message, pretty: true)}")

    {:error,
     %{
       jsonrpc: "2.0",
       id: nil,
       error: %{
         code: -32600,
         message: "Invalid Request",
         data: %{
           received: unknown_message
         }
       }
     }}
  end

  defp safe_call_tool(request_id, params, state_pid) do
    handle_call_tool(request_id, params, state_pid)
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
end
