defmodule Tidewave.MCP.Tools.Ash do
  @moduledoc false

  def tools do
    if Code.ensure_loaded?(Ash) do
      [
        %{
          name: "get_ash_resources",
          description: """
          Returns all Ash domains and their resources for the current project.

          After retrieving the list of resources and their domains, you can use `project_eval` to
          introspect them further. For example:

          - `Spark.extensions(MyApp.MyResource)` - list all extensions on a resource
          - `Ash.Resource.Info.attributes(MyApp.MyResource)` - list all attributes
          - `Ash.Resource.Info.relationships(MyApp.MyResource)` - list all relationships
          - `Ash.Resource.Info.actions(MyApp.MyResource)` - list all actions
          - `Ash.Domain.Info.resources(MyApp.MyDomain)` - list all resources in a domain

          Extensions also provide their own `*.Info` modules for further introspection.
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
