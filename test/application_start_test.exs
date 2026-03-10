defmodule EcsElixirLogsApplicationStartTest do
  use ExUnit.Case

  test "application configuration starts supervision tree" do
    assert [mod: {EcsElixirLogs.Application, []}] =
             Keyword.take(EcsElixirLogs.MixProject.application(), [:mod])
  end
end
