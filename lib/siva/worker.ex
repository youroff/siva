defmodule Siva.Worker do
  use GenServer
  require Logger
  import MonEx.Result

  def start(coordinator) do
    GenServer.start(__MODULE__, coordinator)
  end

  def init(coordinator) do
    GenServer.cast(self(), :init)
    ok(coordinator)
  end

  # Here we have to ask coordinator for job for the first time
  # It either returns a task, which is passed to working handler
  # or registers worker in the waiting queue
  def handle_cast(:init, coordinator) do
    task = GenServer.call(coordinator, {:exchange, nil})
    GenServer.cast(self(), {:job, task})
    {:noreply, coordinator}
  end

  # Do the work if task is some(task), just wait if it's none()
  def handle_cast({:job, task}, coordinator) do
    MonEx.foreach(task, fn t ->
      result = perform(t.payload)
      task = GenServer.call(coordinator, {:exchange, %{t | result: result}})
      GenServer.cast(self(), {:job, task})
    end)
    {:noreply, coordinator}
  end

  # Actual computation, simple calculator with delay simulating heavy computation
  defp perform({op, a, b}) do
    :timer.sleep(1000)
    case op do
      :+ -> a + b
      :/ -> a / b
      :- -> a - b
      :* -> a * b
      _ -> nil
    end
  end
  defp perform(_), do: nil
end
