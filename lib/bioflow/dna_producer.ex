defmodule Bioflow.DNAProducer do
  use GenStage
  require Logger

  @chunk_size 10_000

  def start_link(file_io) do
    GenStage.start_link(__MODULE__, file_io,
      name: {:via, Horde.Registry, {Bioflow.HordeRegistry, :dna_producer}}
    )
  end

  def init(file_io) do
    Logger.info("[DNAProducer] Starting producer")

    {:producer, %{io_device: file_io, active?: false, buffered_demand: 0}}
  end

  def start_stream(pid), do: GenStage.cast(pid, :start_stream)

  def handle_cast(:start_stream, %{buffered_demand: buffered} = state) do
    Logger.info("[DNAProducer] Received start_stream, activating producer")

    if buffered > 0 do
      send(self(), :serve_buffered_demand)
    end

    {:noreply, [], %{state | active?: true}}
  end

  def handle_demand(demand, %{active?: false, buffered_demand: buffered} = state) do
    Logger.debug("[DNAProducer] Received demand #{demand}, but producer not active. Buffering...")
    {:noreply, [], %{state | buffered_demand: buffered + demand}}
  end

  def handle_demand(demand, %{active?: true, io_device: io_device} = state) do
    {chunks, eof?} = read_chunks(io_device, demand)

    if eof? do
      Logger.info("[DNAProducer] End of file reached")
    end

    {:noreply, chunks, state}
  end

  def handle_info(:serve_buffered_demand, %{buffered_demand: buffered} = state)
      when buffered > 0 do
    Logger.debug("[DNAProducer] Serving buffered demand: #{buffered}")
    handle_demand(buffered, %{state | buffered_demand: 0})
  end

  def handle_info(:serve_buffered_demand, state), do: {:noreply, [], state}

  defp read_chunks(io_device, demand) do
    chunks =
      1..demand
      |> Enum.map(fn _ ->
        case IO.read(io_device, @chunk_size) do
          :eof -> nil
          data -> data
        end
      end)
      |> Enum.filter(& &1)

    eof? = chunks == []
    {chunks, eof?}
  end
end
