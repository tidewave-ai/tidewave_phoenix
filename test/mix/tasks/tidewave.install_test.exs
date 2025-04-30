defmodule Mix.Tasks.Tidewave.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "installation warns if no endpoint could be found" do
    test_project()
    |> Igniter.compose_task("tidewave.install")
    |> assert_has_warning(&(&1 =~ "No endpoint found or selected"))
  end

  test "installation adds the plug to the code reloading block" do
    test_project(
      files: %{
        "lib/test_web/endpoint.ex" => """
        defmodule TestWeb.Endpoint do
          use Phoenix.Endpoint, otp_app: :test

          if code_reloading? do
            socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
            plug(Phoenix.LiveReloader)
            plug(Phoenix.CodeReloader)
            plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :tunez)
          end
        end
        """
      }
    )
    |> Igniter.compose_task("tidewave.install")
    |> assert_has_patch("lib/test_web/endpoint.ex", """
    + | if Code.ensure_loaded?(Tidewave) do
    + |   plug(Tidewave)
    + | end
    + |
      | plug(Phoenix.LiveReloader)
    """)
  end

  test "installation warns when it can't find the code reloading block" do
    test_project(
      files: %{
        "lib/test_web/endpoint.ex" => """
        defmodule TestWeb.Endpoint do
          use Phoenix.Endpoint, otp_app: :test
        end
        """
      }
    )
    |> Igniter.compose_task("tidewave.install")
    |> assert_unchanged("lib/test_web/endpoint.ex")
    |> assert_has_warning(
      &(&1 =~
          "Could not find the section of your endpoint `TestWeb.Endpoint` dedicated to dev plugs.")
    )
  end
end
