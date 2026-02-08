defmodule Tidewave.MCP.Tools.Ash do
  @moduledoc false

  def tools do
    if Code.ensure_loaded?(Ash) do
      [
        %{
          name: "get_ash_resources",
          description: """
          Returns all Ash domains and their resources for the current project.

          To find out what extensions a resource has, use `Spark.extensions/1`.

          You can use Info modules like `Ash.Resource.Info` as well as any `*.Info` modules
          from extensions to interrogate individual resources and domains for more details.
          """,
          inputSchema: %{
            type: "object",
            required: [],
            properties: %{}
          },
          callback: &get_ash_resources/1
        }
      ]
    else
      []
    end
  end

  def get_ash_resources(_args) do
    results =
      for app <- apps(),
          {domain, resources} <- apply(Ash.Info, :domains_and_resources, [app]) do
        resource_list =
          Enum.map_join(resources, "\n", fn resource ->
            "    - #{inspect(resource)}"
          end)

        "* #{inspect(domain)}\n#{resource_list}"
      end

    case results do
      [] -> {:error, "No Ash domains or resources found in the project"}
      results -> {:ok, Enum.join(results, "\n\n")}
    end
  end

  defp apps do
    if apps_paths = Mix.Project.apps_paths() do
      Enum.filter(Mix.Project.deps_apps(), &is_map_key(apps_paths, &1))
    else
      [Mix.Project.config()[:app]]
    end
  end
end
