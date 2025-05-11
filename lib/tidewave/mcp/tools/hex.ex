defmodule Tidewave.MCP.Tools.Hex do
  @moduledoc false

  require Logger

  def tools do
    [
      %{
        name: "package_docs_search",
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
        callback: &package_docs_search/1
      },
      %{
        name: "package_search",
        description: """
        Searches for packages on Hex.

        Use this tool if you need to find new packages to add to the project. Before using this tool,
        get an overview of the existing dependencies by using the `get_package_location` tool to find existing dependencies.

        By default, the packages are sorted by popularity (number of downloads).
        """,
        inputSchema: %{
          type: "object",
          required: ["search"],
          properties: %{
            search: %{
              type: "string",
              description: "The search term"
            },
            sort: %{
              type: "string",
              description:
                "Sort parameter (e.g., 'downloads', 'inserted_at', 'updated_at'). Defaults to 'downloads'."
            }
          }
        },
        callback: &package_search/1
      }
    ]
  end

  def package_docs_search(args) do
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
            {:ok, Jason.encode!(body)}

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
    current_otp_app = Mix.Project.config()[:app]

    filter =
      Application.spec(current_otp_app, :applications)
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

  def package_search(args) do
    case args do
      %{"search" => search} ->
        sort = Map.get(args, "sort")

        query_params = %{search: search}
        query_params = if sort, do: Map.put(query_params, :sort, sort), else: query_params
        opts = Keyword.merge(req_opts(), params: query_params)

        case Req.get("https://hex.pm/api/packages", opts) do
          {:ok, %{status: 200, body: %{"packages" => packages}}} ->
            {:ok,
             packages
             |> Enum.map(fn
               %{"name" => name, "latest_version" => version, "downloads" => downloads} ->
                 %{
                   name: name,
                   version: version,
                   downloads: downloads,
                   documentation_uri: "https://hexdocs.pm/#{name}/#{version}"
                 }
             end)
             |> Jason.encode!()}

          {:ok, %{status: status, body: body}} ->
            {:error, "HTTP error #{status} - #{inspect(body)}"}

          {:error, reason} ->
            {:error, "Request failed\n\n#{inspect(reason)}"}
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp req_opts do
    Application.get_env(:tidewave, :hex_req_opts, [])
  end
end
