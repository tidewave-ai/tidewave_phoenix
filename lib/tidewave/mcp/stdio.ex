defmodule Tidewave.MCP.Stdio do
  @moduledoc false

  alias Tidewave.MCP.Handler

  def run(stdio, opts \\ []) do
    assigns = Tidewave.init([])
    proxy? = Keyword.get(opts, :proxy, false)

    handler_opts = [
      include_browser_tools: Keyword.get(opts, :browser_tools, true),
      transform_tools: if(proxy?, do: &add_proxy_ports/1, else: &Function.identity/1)
    ]

    stdio
    |> IO.stream(:line)
    |> Enum.each(&handle_line(&1, stdio, assigns, handler_opts, proxy?))
  end

  defp handle_line(line, stdio, assigns, handler_opts, proxy?) do
    case Jason.decode(line) do
      {:ok, message} ->
        message
        |> handle_message(assigns, handler_opts, proxy?)
        |> write_result(stdio)

      {:error, _error} ->
        write_result(
          {:reply,
           %{
             jsonrpc: "2.0",
             id: nil,
             error: %{code: -32700, message: "Parse error"}
           }},
          stdio
        )
    end
  end

  defp handle_message(
         %{"method" => "tools/call", "id" => id} = message,
         _assigns,
         _handler_opts,
         true
       ) do
    case get_in(message, ["params", "arguments"]) do
      %{"port" => port} = arguments when is_integer(port) and port in 1..65_535 ->
        message = put_in(message, ["params", "arguments"], Map.delete(arguments, "port"))
        proxy_request(message, port)

      _arguments ->
        {:error,
         %{
           jsonrpc: "2.0",
           id: id,
           error: %{code: -32602, message: "Invalid port argument for tool"}
         }}
    end
  end

  defp handle_message(message, assigns, handler_opts, _proxy?) do
    Handler.handle_message(message, assigns, handler_opts)
  end

  defp add_proxy_ports(tools) do
    Enum.map(tools, fn tool ->
      tool
      |> put_in(
        [:inputSchema, :properties, :port],
        %{
          type: "integer",
          description: "The port of the running Phoenix application related to this worktree"
        }
      )
      |> update_in([:inputSchema, :required], fn required ->
        ["port" | required || []]
      end)
    end)
  end

  defp proxy_request(message, port) do
    url = ~c"http://127.0.0.1:#{port}/tidewave/mcp"
    headers = [{~c"content-type", ~c"application/json"}]
    request = {url, headers, ~c"application/json", Jason.encode!(message)}

    case :httpc.request(:post, request, [], body_format: :binary) do
      {:ok, {{_http_version, _status, _reason_phrase}, _headers, body}} ->
        {:reply, Jason.decode!(body)}

      {:error, reason} ->
        {:error,
         %{
           jsonrpc: "2.0",
           id: message["id"],
           error: %{code: -32603, message: "Failed to proxy request: #{inspect(reason)}"}
         }}
    end
  end

  defp write_result(:notification, _stdio), do: :ok

  defp write_result({kind, response}, stdio) when kind in [:reply, :error] do
    IO.write(stdio, [Jason.encode_to_iodata!(response), ?\n])
  end
end
