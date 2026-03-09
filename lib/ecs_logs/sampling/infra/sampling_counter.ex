defmodule SamplingCounter do
  @moduledoc """
  GenServer that owns the ETS sampling counter table and provides counter operations.

  Ensures the table is created at application start and provides an API for
  incrementing and resetting position counters used for sampling decisions.
  """

  use GenServer

  @table :ecs_logs_sampling_counters

  # --- GenServer (table ownership) ---

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    _ = ensure_table!()
    _ = SamplingConfig.fetch_ruleset()
    {:ok, %{}}
  end

  # --- Counter API ---

  def next_position(key, cycle) do
    current =
      :ets.update_counter(
        ensure_table!(),
        key,
        {2, 1, cycle, 1},
        {key, 0}
      )

    current - 1
  end

  def reset! do
    :ets.delete_all_objects(ensure_table!())
    :ok
  end

  def ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      table ->
        table
    end
  end
end
