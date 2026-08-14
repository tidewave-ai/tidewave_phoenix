defmodule Tidewave.MCP.Tools.DesignCanvas do
  @moduledoc false

  def tools do
    [
      %{
        name: "create_design_canvas",
        description: """
        Creates a new design canvas, an HTML file for presenting design explorations.

        The tool returns the absolute path of the HTML file. The file includes usage
        instructions, read it, then edit it to author the actual design.
        """,
        inputSchema: %{
          type: "object",
          required: ["path"],
          properties: %{
            path: %{
              type: "string",
              description:
                "The absolute path for the canvas file, with .html file extension. The file must not exist yet."
            }
          }
        },
        callback: &create_design_canvas/1
      }
    ]
  end

  def create_design_canvas(args) do
    case args do
      %{"path" => path} when is_binary(path) ->
        if Path.type(path) == :absolute and String.ends_with?(path, ".html") do
          with {:ok, html} <- fetch_canvas_html(),
               :ok <- write_canvas(path, html) do
            {:ok,
             "Design canvas created at: <path>#{path}</path>. Read the file for usage instructions."}
          end
        else
          {:error,
           "Invalid path #{inspect(path)}. It must be an absolute path with the .html file extension."}
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp write_canvas(path, html) do
    with :ok <- mkdir(Path.dirname(path)) do
      case File.write(path, html, [:exclusive]) do
        :ok ->
          :ok

        {:error, :eexist} ->
          {:error, "Failed to create the design canvas file, the file already exists."}

        {:error, reason} ->
          {:error, "Failed to create the design canvas file: #{:file.format_error(reason)}"}
      end
    end
  end

  defp mkdir(path) do
    case File.mkdir_p(path) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Failed to create the design canvas directory: #{:file.format_error(reason)}"}
    end
  end

  defp fetch_canvas_html do
    {:ok, _} = Application.ensure_all_started([:inets, :ssl])

    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")
    url = client_url <> "/tc/data/canvas.json"

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      timeout: 15_000
    ]

    case :httpc.request(:get, {String.to_charlist(url), []}, http_options, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        case Jason.decode(body) do
          {:ok, %{"html" => html}} when is_binary(html) ->
            {:ok, html}

          _ ->
            {:error,
             "Failed to fetch the design canvas template, unexpected response from #{url}"}
        end

      {:ok, {{_, status, _}, _headers, _body}} ->
        {:error,
         "Failed to fetch the design canvas template, request to #{url} failed with status #{status}"}

      {:error, reason} ->
        {:error,
         "Failed to fetch the design canvas template, request to #{url} failed: #{inspect(reason)}"}
    end
  end
end
