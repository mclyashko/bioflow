defmodule Bioflow.DNAFlow do
  @worker_count 8
  @timeout 10_000_000

  # Bioflow.DNAFlow.analyze_distributed("/Users/viktor/Documents/статьи/бим_и_днк/bioflow/dna_sequence.txt")
  def analyze_distributed(file_path) do
    with {:ok, io_device} <- File.open(file_path, [:read, :utf8]),
         %File.Stat{size: total} <- File.stat!(file_path),
         {:ok, producer_pid} <- start_producer(io_device),
         :ok <- start_workers(@worker_count),
         {:ok, _aggregator_pid} <- start_aggregator({self(), total}),
         [{^producer_pid, _}] <- Horde.Registry.lookup(Bioflow.HordeRegistry, :dna_producer),
         :ok <- Bioflow.DNAProducer.start_stream(producer_pid) do
      start_time = System.monotonic_time(:millisecond)

      result =
        receive do
          {:final_result, result} -> {:ok, result}
        after
          @timeout -> {:error, :timeout}
        end

      end_time = System.monotonic_time(:millisecond)
      IO.puts("Time waited for result: #{end_time - start_time} ms")

      File.close(io_device)

      terminate_all_children()

      result
    else
      {:error, reason} -> {:error, reason}
      [] -> {:error, :producer_not_found}
    end
  end

  defp start_producer(io_device, timeout \\ 5_000) do
    case Horde.DynamicSupervisor.start_child(
           Bioflow.HordeSupervisor,
           %{
             id: Bioflow.DNAProducer,
             start: {Bioflow.DNAProducer, :start_link, [io_device]},
             type: :worker,
             restart: :transient
           }
         ) do
      {:ok, pid} -> wait_for_registry(:dna_producer, pid, timeout)
      {:error, reason} -> {:error, {:producer_start_failed, reason}}
    end
  end

  defp start_workers(count, timeout \\ 5_000) do
    Enum.each(1..count, fn i ->
      case Horde.DynamicSupervisor.start_child(
             Bioflow.HordeSupervisor,
             %{
               id: {:dna_worker, i},
               start: {Bioflow.DNAWorker, :start_link, [i]},
               type: :worker,
               restart: :transient
             }
           ) do
        {:ok, pid} -> wait_for_registry({:dna_worker, i}, pid, timeout)
        {:error, reason} -> raise "Failed to start worker #{i}: #{inspect(reason)}"
      end
    end)

    :ok
  end

  defp start_aggregator(callerAndTotal, timeout \\ 5_000) do
    case Horde.DynamicSupervisor.start_child(
           Bioflow.HordeSupervisor,
           %{
             id: Bioflow.DNAAggregator,
             start: {Bioflow.DNAAggregator, :start_link, [callerAndTotal]},
             type: :worker,
             restart: :transient
           }
         ) do
      {:ok, pid} -> wait_for_registry(:dna_aggregator, pid, timeout)
      {:error, reason} -> {:error, {:aggregator_start_failed, reason}}
    end
  end

  defp wait_for_registry(_name, pid, timeout) do
    :timer.sleep(timeout)
    {:ok, pid}
  end

  defp terminate_all_children do
    Bioflow.HordeSupervisor
    |> Horde.DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _type, _modules} ->
      Process.exit(pid, :normal)
    end)
  end
end
