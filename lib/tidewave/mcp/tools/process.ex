defmodule Tidewave.MCP.Tools.Process do
  @moduledoc false

  def tools do
    [
      %{
        name: "get_process_info",
        description: """
        Returns detailed information about a process. Either a pid or a name must be provided.

        Use this tool to find out more about a process, for example to debug a problem with a specific
        LiveView or named GenServer.
        """,
        inputSchema: %{
          type: "object",
          required: [],
          properties: %{
            pid: %{
              type: "string",
              description: "The pid to get info for, e.g. '#PID<0.123.0>'."
            },
            name: %{
              type: "string",
              description:
                "The registered name of the process to get info for, e.g. 'Elixir.MyApp.MyServer'."
            }
          }
        },
        callback: &get_process_info/1
      }
    ] ++
      if can_trace?() do
        [
          %{
            name: "trace_process",
            description: """
            Traces messages sent to and from a process until the specified message count is reached.

            This is a very specific tool, use it only if the user needs to debug something happening in a
            process like a GenServer or a LiveView and is not sure what's going on. When you try to use the tool, inform the
            user that you are going to trace the process, and ask them to perform the action they're having
            problems with after starting the tool call. Start with a low message count, for example 10 and
            only increase it if necessary.

            This tool blocks the execution until the specified number of messages has been traced or the timeout is reached.
            """,
            inputSchema: %{
              type: "object",
              required: ["pid", "message_count", "timeout"],
              properties: %{
                pid: %{
                  type: "string",
                  description: "The pid of the process to trace, e.g. '#PID<0.123.0>'."
                },
                message_count: %{
                  type: "integer",
                  description: "Number of messages to trace before stopping. Defaults to 50.",
                  minimum: 1
                },
                timeout: %{
                  type: "integer",
                  description: "Timeout in milliseconds. Defaults to 30000."
                }
              }
            },
            callback: &trace_process/2
          }
        ]
      else
        []
      end
  end

  # Helper function to parse PID from string
  defp parse_pid(pid_string) do
    {:ok, IEx.Helpers.pid(pid_string)}
  rescue
    e -> {:error, "Could not parse pid: #{Exception.format(:error, e, __STACKTRACE__)}"}
  end

  @process_info_keys_and_labels [
    {:initial_call, "Initial call"},
    {:dictionary, "Dictionary"},
    {:links, "Links"},
    {:monitors, "Monitors"},
    {:monitored_by, "Monitored by"},
    {:registered_name, "Registered name"},
    {:current_function, "Current function"},
    {:status, "Status"},
    {:message_queue_len, "Message queue length"},
    {:trap_exit, "Trap exit"},
    {:error_handler, "Error handler"},
    {:priority, "Priority"},
    {:group_leader, "Group leader"},
    {:total_heap_size, "Total heap size"},
    {:heap_size, "Heap size"},
    {:stack_size, "Stack size"},
    {:reductions, "Reductions"},
    {:garbage_collection, "Garbage collection"},
    {:suspending, "Suspending"},
    {:current_stacktrace, "Current stacktrace"}
  ]
  @process_info_keys Enum.map(@process_info_keys_and_labels, fn {key, _} -> key end)
  @process_info_label_mapping Map.new(@process_info_keys_and_labels)

  @doc """
  Gets detailed information about a specific process.
  """
  def get_process_info(args) do
    case args do
      %{"pid" => pid_string} ->
        process_info(pid_string)

      %{"name" => name} ->
        process_info(name)

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp process_info(pid_or_name) do
    maybe_pid =
      case pid_or_name do
        <<"#PID<", _rest::binary>> = pid ->
          parse_pid(pid)

        name ->
          whereis(String.to_atom(name))
      end

    with {:ok, pid} <- maybe_pid,
         :ok <- alive?(pid),
         {:ok, info} <- info(pid, @process_info_keys) do
      text =
        for pair <- info, text = process_info_to_text(pair), not is_nil(text), do: text

      {:ok, Enum.join(text, "\n")}
    end
  end

  defp whereis(name) do
    if pid = Process.whereis(name) do
      {:ok, pid}
    else
      {:error, "Process not found"}
    end
  end

  defp alive?(pid) do
    if Process.alive?(pid) do
      :ok
    else
      {:error, "Process is not alive"}
    end
  end

  defp info(pid, keys) do
    case Process.info(pid, keys) do
      info when is_list(info) ->
        {:ok, info}

      _ ->
        {:error, "Failed to get process info"}
    end
  end

  def can_trace? do
    Code.ensure_loaded?(:trace) and function_exported?(:trace, :session_create, 3)
  end

  @doc """
  Traces messages sent to and from a process until the specified number of messages have been traced.

  Uses Erlang's trace module (OTP 27+) to monitor messages for the given process. The trace will
  automatically stop after capturing the specified number of messages.

  Note: This function requires OTP 27 or later.
  """
  def trace_process(args, assigns) do
    case args do
      %{"pid" => pid_string, "message_count" => message_count}
      when is_binary(pid_string) and is_integer(message_count) ->
        with {:ok, pid} <- parse_pid(pid_string),
             :ok <- alive?(pid) do
          timeout = Map.get(args, "timeout", 30_000)
          do_trace(pid, message_count, timeout, assigns.inspect_opts)
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp do_trace(pid, message_count, timeout, inspect_opts) do
    timer_ref = Process.send_after(self(), :timeout, timeout)

    try do
      # Create a unique name for this trace session
      session_name = :"trace_session_#{System.unique_integer([:positive])}"
      session = apply(:trace, :session_create, [session_name, self(), []])

      # Enable send and receive tracing for the specified process with timestamps
      # TODO: remove apply calls and directly call the functions once we require OTP 27+
      apply(:trace, :process, [session, pid, true, [:send, :receive, :timestamp]])

      # Create a collector process that will gather trace messages up to the specified count
      {prefix, result} = collector_loop(message_count, [])
      apply(:trace, :session_destroy, [session])

      text =
        Enum.map_join(result, "\n", fn
          {:trace_ts, traced_pid, :send, message, to_pid, timestamp} ->
            time_str = format_timestamp(timestamp)

            "#{time_str} #{inspect(traced_pid)} sent #{inspect(message, inspect_opts)} to #{inspect(to_pid)}"

          {:trace_ts, traced_pid, :receive, message, timestamp} ->
            time_str = format_timestamp(timestamp)
            "#{time_str} #{inspect(traced_pid)} received #{inspect(message, inspect_opts)}"

          other ->
            "Other trace: #{inspect(other)}"
        end)

      {:ok, "#{prefix}#{text}"}
    after
      Process.cancel_timer(timer_ref)
    end
  end

  # Format timestamp tuple to a readable string
  defp format_timestamp({megasec, sec, microsec}) do
    {_, {hour, minute, second}} = :calendar.now_to_datetime({megasec, sec, microsec})

    "#{String.pad_leading("#{hour}", 2, "0")}:#{String.pad_leading("#{minute}", 2, "0")}:#{String.pad_leading("#{second}", 2, "0")}.#{div(microsec, 1000)}"
  end

  defp collector_loop(0, messages) do
    {"", Enum.reverse(messages)}
  end

  defp collector_loop(count, messages) do
    receive do
      :timeout ->
        {"Timed out waiting for more messages. The existing messages are:\n\n",
         Enum.reverse(messages)}

      {:trace_ts, _pid, :send, _msg, _to_pid, _ts} = trace_msg ->
        collector_loop(count - 1, [trace_msg | messages])

      {:trace_ts, _pid, :receive, _msg, _ts} = trace_msg ->
        collector_loop(count - 1, [trace_msg | messages])
    after
      5000 ->
        # Early exit after 5 seconds of no trace messages
        {"Timed out after 5 seconds of no trace messages. The existing messages are:\n\n",
         Enum.reverse(messages)}
    end
  end

  ### Helpers to format process info (inspired by Phoenix.LiveDashboard)

  defp process_info_to_text({:links, links}) do
    case Enum.map_join(links, "\n  ", &pid_or_port_details/1) do
      "" -> nil
      links -> "Links:\n  #{links}"
    end
  end

  defp process_info_to_text({:monitors, monitors}) do
    monitors =
      monitors
      |> Enum.map(fn {_label, pid_or_port} -> pid_or_port end)
      |> Enum.map_join("\n  ", &pid_or_port_details/1)

    case monitors do
      "" -> nil
      _ -> "Monitors:\n  " <> monitors
    end
  end

  defp process_info_to_text({:monitored_by, monitored_by}) do
    monitored_by = Enum.map_join(monitored_by, "\n  ", &pid_or_port_details/1)

    case monitored_by do
      "" -> nil
      _ -> "Monitored by:\n  " <> monitored_by
    end
  end

  defp process_info_to_text({:group_leader, group_leader}),
    do: "Group leader: #{pid_or_port_details(group_leader)}"

  defp process_info_to_text({:dictionary, dictionary}) do
    ancestors = Keyword.get(dictionary, :"$ancestors", [])

    case ancestors do
      [] -> nil
      _ -> "Ancestors:\n  " <> Enum.map_join(ancestors, "\n  ", &pid_or_port_details/1)
    end
  end

  defp process_info_to_text({:current_stacktrace, stacktrace}),
    do: "Stacktrace:\n#{Exception.format_stacktrace(stacktrace)}"

  defp process_info_to_text({key, value}),
    do: "#{@process_info_label_mapping[key]}: #{inspect(value)}"

  defp pid_or_port_details(pid) when is_pid(pid), do: to_process_details(pid)
  defp pid_or_port_details(name) when is_atom(name), do: to_process_details(name)
  defp pid_or_port_details(port) when is_port(port), do: to_port_details(port)
  defp pid_or_port_details(reference) when is_reference(reference), do: reference

  defp to_process_details(pid) when is_pid(pid) do
    name_or_initial_call =
      case Process.info(pid, [:initial_call, :dictionary, :registered_name]) do
        [{:initial_call, initial_call}, {:dictionary, dictionary}, {:registered_name, name}] ->
          initial_call = Keyword.get(dictionary, :"$initial_call", initial_call)

          format_registered_name(name) ||
            format_process_label(Keyword.get(dictionary, :"$process_label")) ||
            format_initial_call(initial_call)

        _ ->
          nil
      end

    if name_or_initial_call do
      "#{inspect(pid)} (#{name_or_initial_call})"
    else
      inspect(pid)
    end
  end

  defp to_process_details(name) when is_atom(name) do
    Process.whereis(name)
    |> to_process_details()
  end

  defp format_process_label(nil), do: nil
  defp format_process_label(label) when is_binary(label), do: label
  defp format_process_label(label), do: inspect(label)

  defp format_registered_name([]), do: nil
  defp format_registered_name(name), do: inspect(name)

  defp format_initial_call({:supervisor, mod, arity}), do: Exception.format_mfa(mod, :init, arity)
  defp format_initial_call({m, f, a}), do: Exception.format_mfa(m, f, a)
  defp format_initial_call(nil), do: nil

  defp to_port_details(port) when is_port(port) do
    description =
      case Port.info(port, :name) do
        {:name, name} -> name
        _ -> port
      end

    "Port: #{inspect(port)} (#{inspect(description)})"
  end
end
