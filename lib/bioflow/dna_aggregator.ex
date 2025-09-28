defmodule Bioflow.DNAAggregator do
  use GenStage
  require Logger

  @min_demand 0
  @max_demand 50

  def start_link({caller_pid, total}) do
    GenStage.start_link(
      __MODULE__,
      {caller_pid, total},
      name: {:via, Horde.Registry, {Bioflow.HordeRegistry, :dna_aggregator}}
    )
  end

  def init({caller_pid, total}) do
    workers =
      Horde.Registry.select(Bioflow.HordeRegistry, [
        {{:"$1", :_, :_}, [{:==, {:binary_part, :"$1", 0, 11}, "dna_worker_"}], [:"$1"]}
      ])

    Logger.info("[DNAAggregator] Starting, subscribing to workers: #{inspect(workers)}")

    subscriptions =
      Enum.map(workers, fn worker_name ->
        {{:via, Horde.Registry, {Bioflow.HordeRegistry, worker_name}},
         min_demand: @min_demand, max_demand: @max_demand}
      end)

    state = %{caller: caller_pid, total: total, result: %{"A" => 0, "C" => 0, "G" => 0, "T" => 0}}

    {:consumer, state, subscribe_to: subscriptions}
  end

  def handle_events(events, _from, state) do
    Logger.debug("[DNAAggregator] Received events: #{inspect(events)}")

    new_result =
      Enum.reduce(events, state.result, fn counts, acc ->
        Map.merge(acc, counts, fn _k, v1, v2 -> v1 + v2 end)
      end)

    Logger.debug("[DNAAggregator] Updated aggregated result: #{inspect(new_result)}")

    total_count = Enum.sum(Map.values(new_result))

    if total_count >= state.total do
      Logger.info("[DNAAggregator] Total reached: #{total_count}, sending result to caller")
      send(state.caller, {:final_result, new_result})
    end

    {:noreply, [], %{state | result: new_result}}
  end
end
