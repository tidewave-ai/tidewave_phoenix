defmodule Tidewave.MCP.Tools.Hex do
  @moduledoc false

  require Logger

  def tools do
    [
      %{
        name: "search_package_docs",
        description: """
        Searches Hex documentation for the project's dependencies or a list of packages.

        If you're trying to get documentation for a specific module or function, first try the `project_eval` tool with the `h` helper.
        """,
        inputSchema: %{
          type: "object",
          required: ["q"],
          properties: %{
            q: %{
              type: "string",
              description: "The search query"
            },
            packages: %{
              type: "array",
              items: %{
                type: "string"
              },
              description: """
              Optional. The list of package names to filter the search results, e.g. ['phoenix'].
              If not provided, the search will be performed on all dependencies of the project, which is a good default.
              """
            }
          }
        },
        callback: &search_package_docs/1
      }
    ]
  end

  def search_package_docs(args) do
    case args do
      %{"q" => q} ->
        filter_by =
          case args["packages"] do
            p when p in [nil, []] ->
              filter_from_mix_lock()

            packages ->
              filter_from_packages(packages)
          end

        # Build query params
        query_params = %{
          q: q,
          query_by: "doc,title",
          filter_by: filter_by
        }

        # Make the HTTP request with Req
        opts = Keyword.merge(req_opts(), params: query_params)

        case Req.get("https://search.hexdocs.pm/", opts) do
          {:ok, %{status: 200, body: body}} ->
            {:ok, format_results(body)}

          {:ok, %{status: status, body: body}} ->
            {:error, "HTTP error #{status} - #{inspect(body)}"}

          {:error, reason} ->
            {:error, "Request failed\n\n#{inspect(reason)}"}
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp filter_from_mix_lock do
    apps =
      if apps_paths = Mix.Project.apps_paths() do
        Enum.filter(Mix.Project.deps_apps(), &is_map_key(apps_paths, &1))
      else
        [Mix.Project.config()[:app]]
      end

    filter =
      apps
      |> Enum.flat_map(fn app ->
        Application.load(app)
        Application.spec(app, :applications)
      end)
      |> Enum.uniq()
      |> Enum.map(fn app ->
        "#{app}-#{Application.spec(app, :vsn)}"
      end)
      |> Enum.join(", ")

    "package:=[#{filter}]"
  end

  defp filter_from_packages(packages) do
    filter =
      packages
      |> Enum.flat_map(fn package ->
        case Req.get("https://hex.pm/api/packages/#{package}", req_opts()) do
          {:ok, %{status: 200, body: body}} ->
            ["#{package}-#{get_latest_version(body)}"]

          other ->
            Logger.warning(
              "Failed to get latest version for package #{package}: #{inspect(other)}"
            )

            []
        end
      end)
      |> Enum.join(", ")

    "package:=[#{filter}]"
  end

  defp get_latest_version(package) do
    versions =
      for release <- package["releases"],
          version = Version.parse!(release["version"]),
          # ignore pre-releases like release candidates, etc.
          version.pre == [] do
        version
      end

    Enum.max(versions, Version)
  end

  defp req_opts do
    Application.get_env(:tidewave, :hex_req_opts, [])
  end

  defp format_results(body) do
    %{"found" => found, "hits" => hits} = body

    result = "Results: #{found}"

    hits
    |> Enum.with_index()
    |> Enum.reduce(result, fn {hit, index}, result ->
      %{
        "document" => %{
          "doc" => doc,
          "package" => package,
          "ref" => ref,
          "title" => title
        }
      } = hit

      result <>
        "\n\n" <>
        """
        <result index="#{index}" package="#{package}" ref="#{ref}" title="#{title}">
        #{doc}
        </result>
        """
    end)
  end
end
