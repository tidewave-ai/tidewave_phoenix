defmodule Tidewave.MCP.Tools.Phoenix do
  @moduledoc false

  def tools do
    [
      %{
        name: "list_liveview_pages",
        description: """
        Returns a list of currently connected LiveViews.

        Use this tool if the project is using Phoenix LiveView and a user talks about something
        that is happening in the current page or the current LiveView.
        """,
        inputSchema: %{
          type: "object",
          properties: %{},
          required: []
        },
        callback: &list_liveview_pages/2
      }
    ]
  end

  def list_liveview_pages(_args, assigns) do
    liveviews =
      for process <- Process.list(),
          result = liveview_process?(process),
          match?({_state, true}, result) do
        {state, _} = result
        extract_liveview_info(process, state)
      end

    case liveviews do
      [] ->
        {:ok, "There are no LiveView processes connected!"}

      liveviews ->
        {:ok, inspect(liveviews, assigns.inspect_opts)}
    end
  end

  defp liveview_process?(pid) do
    # First, check the initial call to identify potential LiveView processes
    with info when is_list(info) <- Process.info(pid, [:dictionary]),
         {:dictionary, dictionary} <- List.keyfind(info, :dictionary, 0),
         {:"$ancestors", ancestors} <- List.keyfind(dictionary, :"$ancestors", 0),
         {:"$initial_call", initial_call} <- List.keyfind(dictionary, :"$initial_call", 0),
         true <- liveview_initial_call?(initial_call),
         true <-
           Enum.any?(ancestors, fn ancestor ->
             is_atom(ancestor) and inspect(ancestor) =~ "Phoenix.LiveView.Socket"
           end) do
      # Then verify by checking if the process state has a LiveView socket
      try do
        case :sys.get_state(pid, 500) do
          %{socket: %struct{}} = state when struct == Phoenix.LiveView.Socket -> {state, true}
          _ -> {nil, false}
        end
      catch
        :exit, _ -> {nil, true}
      end
    else
      _ -> {nil, false}
    end
  rescue
    # Process might have terminated during inspection
    _ -> {nil, false}
  end

  defp liveview_initial_call?({_mod, :mount, _}), do: true
  defp liveview_initial_call?(_), do: false

  defp extract_liveview_info(pid, nil) do
    info = Process.info(pid, [:message_queue_len, :memory])

    %{
      pid: inspect(pid),
      memory: info[:memory],
      message_queue_len: info[:message_queue_len],
      state:
        "Could not get state, maybe the process is busy? Try looking at the current_stacktrace from get_process_info."
    }
  end

  defp extract_liveview_info(pid, state) do
    info = Process.info(pid, [:message_queue_len, :memory])
    socket = state.socket
    assigns = socket.assigns || %{}
    view = socket.view

    %{
      pid: inspect(pid),
      view: view,
      live_action: is_map(assigns) && assigns[:live_action],
      module: view,
      memory: info[:memory],
      message_queue_len: info[:message_queue_len]
    }
  end
end
