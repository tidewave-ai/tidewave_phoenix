defmodule Tidewave.MockTool do
  def tools do
    [
      %{
        name: "mock_tool",
        description: """
        mock_tool
        """,
        inputSchema: %{
          type: "object",
          required: ["q"],
          properties: %{
            q: %{
              type: "string",
              description: "mock_description"
            },
            packages: %{
              type: "array",
              items: %{
                type: "string"
              },
              description: """
              mock_description
              """
            }
          }
        },
        callback: &mock_callback/1
      }
    ]
  end

  def mock_callback(_args) do
    {:ok, "mock_tool"}
  end
end
