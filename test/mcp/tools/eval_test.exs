defmodule Tidewave.MCP.Tools.EvalTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Eval

  describe "project_eval/2" do
    test "evaluates simple Elixir expressions" do
      code = "1 + 1"

      assert {:ok, "2"} = Eval.project_eval(%{"code" => code}, Tidewave.init([]))
    end

    test "evaluates complex Elixir expressions" do
      code = """
      defmodule Temp do
        def add(a, b), do: a + b
      end

      Temp.add(40, 2)
      """

      assert {:ok, "42"} = Eval.project_eval(%{"code" => code}, Tidewave.init([]))
    end

    test "returns formatted errors for exceptions" do
      code = "1 / 0"

      assert {:ok, error} = Eval.project_eval(%{"code" => code}, Tidewave.init([]))
      assert error =~ "ArithmeticError"
      assert error =~ "bad argument in arithmetic expression"
    end

    test "can use IEx helpers" do
      code = "h Tidewave"

      assert {:ok, docs} = Eval.project_eval(%{"code" => code}, Tidewave.init([]))

      assert docs =~ "Tidewave"
    end

    test "catches exits" do
      assert {:error, "Failed to evaluate code. Process exited with reason: :brutal_kill"} =
               Eval.project_eval(
                 %{"code" => "Process.exit(self(), :brutal_kill)"},
                 Tidewave.init([])
               )
    end

    test "times out" do
      assert {:error, "Evaluation timed out after 50 milliseconds."} =
               Eval.project_eval(
                 %{"code" => "Process.sleep(10_000)", "timeout" => 50},
                 Tidewave.init([])
               )
    end

    test "returns IO up to exception" do
      assert {:ok, result} =
               Eval.project_eval(%{"code" => ~s[IO.puts("Hello!"); 1 / 0]}, Tidewave.init([]))

      assert result =~ "Hello!"
      assert result =~ "ArithmeticError"
    end

    test "captures standard_error" do
      assert {:ok, result} =
               Eval.project_eval(
                 %{"code" => "hello"},
                 Tidewave.init([])
               )

      assert result =~ "undefined variable \"hello\""
    end

    test "supports arguments" do
      assert {:ok, result} =
               Eval.project_eval(
                 %{"code" => "arguments", "arguments" => [1, "2"]},
                 Tidewave.init([])
               )

      assert result == "[1, \"2\"]"
    end
  end

  describe "project_eval/2 (structured)" do
    test "evaluates Elixir expressions" do
      code = "1 + 1"

      assert {:ok, result} =
               Eval.project_eval(%{"code" => code, "json" => true}, Tidewave.init([]))

      assert Jason.decode!(result) == %{
               "result" => 2,
               "success" => true,
               "stdout" => "",
               "stderr" => ""
             }
    end

    test "returns formatted errors for exceptions" do
      code = "1 / 0"

      assert {:ok, error} =
               Eval.project_eval(%{"code" => code, "json" => true}, Tidewave.init([]))

      decoded = Jason.decode!(error)
      assert decoded["success"] == false
      assert decoded["result"] =~ "ArithmeticError"
      assert decoded["result"] =~ "bad argument in arithmetic expression"
    end

    test "catches exits" do
      assert {:error, "Failed to evaluate code. Process exited with reason: :brutal_kill"} =
               Eval.project_eval(
                 %{"code" => "Process.exit(self(), :brutal_kill)", "json" => true},
                 Tidewave.init([])
               )
    end

    test "times out" do
      assert {:error, "Evaluation timed out after 50 milliseconds."} =
               Eval.project_eval(
                 %{"code" => "Process.sleep(10_000)", "timeout" => 50, "json" => true},
                 Tidewave.init([])
               )
    end

    test "returns IO up to exception" do
      assert {:ok, result} =
               Eval.project_eval(
                 %{"code" => ~s[IO.puts("Hello!"); 1 / 0], "json" => true},
                 Tidewave.init([])
               )

      decoded = Jason.decode!(result)
      assert decoded["success"] == false
      assert decoded["stdout"] =~ "Hello!"
      assert decoded["result"] =~ "ArithmeticError"
    end

    test "captures standard_error" do
      assert {:ok, result} =
               Eval.project_eval(
                 %{"code" => "hello", "json" => true},
                 Tidewave.init([])
               )

      decoded = Jason.decode!(result)
      assert decoded["success"] == false
      assert decoded["stdout"] =~ "undefined variable \"hello\""
    end

    test "suports arguments" do
      assert {:ok, result} =
               Eval.project_eval(
                 %{"code" => "arguments", "arguments" => [1, "2"], "json" => true},
                 Tidewave.init([])
               )

      assert Jason.decode!(result) == %{
               "result" => [1, "2"],
               "success" => true,
               "stdout" => "",
               "stderr" => ""
             }
    end
  end
end
