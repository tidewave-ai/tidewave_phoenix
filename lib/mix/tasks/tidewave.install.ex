defmodule Mix.Tasks.Tidewave.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs `tidewave` into your project"
  end

  def example do
    "mix igniter.install tidewave"
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Tidewave.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc false
    @plug_example """
    + if Code.ensure_loaded?(Tidewave) do
    +   plug Tidewave
    + end

    if code_reloading? do
      socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
      plug Phoenix.LiveReloader
      plug Phoenix.CodeReloader
      plug Phoenix.Ecto.CheckRepoStatus, otp_app: :my_app
    end
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :tidewave,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> setup_phoenix()
      |> Igniter.add_notice("""
      Tidewave next steps:

      * Enable Tidewave in your editor: https://hexdocs.pm/tidewave/mcp.html
      """)
    end

    defp setup_phoenix(igniter) do
      {igniter, endpoint} =
        Igniter.Libs.Phoenix.select_endpoint(
          igniter,
          nil,
          "Which endpoint should serve your tidewave MCP?"
        )

      if endpoint do
        add_plug_to_endpoint(igniter, endpoint)
      else
        Igniter.add_warning(igniter, """
        No endpoint found or selected for tidewave setup. Please add the plug manually, for example:

        #{@plug_example}
        """)
      end
    end

    defp add_plug_to_endpoint(igniter, endpoint) do
      Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        with :error <-
               Igniter.Code.Common.move_to(zipper, fn zipper ->
                 Igniter.Code.Function.function_call?(zipper, :plug) and
                   Igniter.Code.Function.argument_equals?(zipper, 0, Tidewave)
               end),
             {:ok, zipper} <- Igniter.Code.Common.move_to(zipper, &code_reloading?/1) do
          {:ok,
           Igniter.Code.Common.add_code(
             zipper,
             """
             if Code.ensure_loaded?(Tidewave) do
               plug Tidewave
             end
             """,
             placement: :before
           )}
        else
          {:ok, _} ->
            {:ok, zipper}

          :error ->
            {:warning,
             """
             Could not find the section of your endpoint `#{inspect(endpoint)}` dedicated to code reloading.
             We look for `if code_reloading? do`, but you may have customized this code.
             Please add the plug manually, for example:

             #{@plug_example}
             """}
        end
      end)
    end

    defp code_reloading?(zipper) do
      Igniter.Code.Function.function_call?(
        zipper,
        :if,
        2
      ) &&
        Igniter.Code.Function.argument_matches_predicate?(
          zipper,
          0,
          &Igniter.Code.Common.variable?(&1, :code_reloading?)
        )
    end
  end
else
  defmodule Mix.Tasks.Tidewave.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'tidewave.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
