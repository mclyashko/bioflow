defmodule Bioflow.DNAWorker do
  use GenStage
  require Logger

  @min_demand 0
  @max_demand 25

  @nucleotides ["A", "C", "G", "T"]

  def start_link(worker_id) do
    name = {:via, Horde.Registry, {Bioflow.HordeRegistry, "dna_worker_#{worker_id}"}}
    GenStage.start_link(__MODULE__, worker_id, name: name)
  end

  def init(worker_id) do
    producer = {:via, Horde.Registry, {Bioflow.HordeRegistry, :dna_producer}}
    Logger.info("[DNAWorker #{worker_id}] Starting and subscribing to producer")

    {:producer_consumer, %{worker_id: worker_id},
     subscribe_to: [{producer, min_demand: @min_demand, max_demand: @max_demand}]}
  end

  def handle_events(chunks, _from, %{worker_id: worker_id} = state) do
    counts = count_nucleotides(chunks)

    Logger.debug("[DNAWorker #{worker_id}] Processed counts: #{inspect(counts)}")

    {:noreply, [counts], state}
  end

  defp count_nucleotides(chunks) when is_list(chunks) do
    chunks
    |> Flow.from_enumerable()
    |> Flow.flat_map(&String.graphemes(String.upcase(&1)))
    |> Flow.filter(&(&1 in @nucleotides))
    |> Flow.partition()
    |> Flow.reduce(
      fn -> %{"A" => 0, "C" => 0, "G" => 0, "T" => 0} end,
      fn char, acc -> Map.update!(acc, char, &(&1 + 1)) end
    )
    |> Enum.to_list()
    |> Enum.reduce(%{"A" => 0, "C" => 0, "G" => 0, "T" => 0}, fn {char, count}, acc ->
      Map.update(acc, char, count, &(&1 + count))
    end)
  end
end
