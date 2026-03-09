defmodule EcsElixirLogs.Application do
  @moduledoc """
  Please see readme
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SamplingCounter
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EcsElixirLogs.Supervisor)
  end
end
