defmodule Siva.Coordinator do
  use GenServer
  import MonEx.{Option, Result}
  alias Siva.Task
  require Logger

  def start_link do
    GenServer.start_link __MODULE__, [], name: Siva
  end

  @max_queue Application.get_env(:siva, :max_queue)
  @max_workers Application.get_env(:siva, :max_workers)

  def init(_) do
    Siva.Scaler.start_link(self())
    ok(%{
      workers: :queue.new(),
      tasks: :queue.new(),
      working_tasks: [],
      task_counter: 0
    })
  end

  # Processes call from client
  # retruns %Task{tag: unique id, ...}
  # If there are waiting workers, sends it directly to worker
  # Otherwise puts it to the queue
  def handle_call({:enqueue, payload}, {from, _}, state) do
    if :queue.len(state.tasks) < @max_queue do
      state = inc_task_counter(state)
      task = %Task{tag: state.task_counter, payload: payload, owner: from}

      case pop(state, :workers) do
        {some(worker), state} ->
          task = %{task | worker: worker}
          state = %{state | working_tasks: [task | state.working_tasks]}
          GenServer.cast(worker, {:job, some(task)})
          {:reply, task, state}
        {none(), state} ->
          state = %{state | tasks: :queue.in(task, state.tasks)}
          {:reply, task, state}
      end
    else
      {:reply, :queue_full, state}
    end
  end

  # Passes waiting worker from queue to scaler for killing
  def handle_call(:release_worker, _, state) do
    {worker, state} = pop(state, :workers)
    {:reply, worker, state}
  end

  # Call from worker
  # If task is none(), just asks for task from queue or hold worker in waiting queue
  # If task is some(task), notify owner of completion
  def handle_call({:exchange, task}, {worker, _}, state) do
    {found, state} = lookup_task(state, task, worker)
    MonEx.foreach(found, &GenServer.cast(&1.owner, {:result, &1}))

    case pop(state, :tasks) do
      {some(task), state} ->
        task = %{task | worker: worker}
        state = %{state | working_tasks: [task | state.working_tasks]}
        {:reply, some(task), state}
      {none(), state} ->
        state = %{state | workers: :queue.in(worker, state.workers)}
        {:reply, none(), state}
    end
  end

  # Stats call, simply returns tuple with tasks queue, and workers queue length
  def handle_call(:stats, _, state) do
    {:reply, {:queue.len(state.tasks), :queue.len(state.workers)}, state}
  end

  # Takes element from queue, returns Option(element) and updated state
  defp pop(state, type \\ :workers) when type in [:workers, :tasks] do
    {item, queue} = queue_pop(state[type])
    {item, Map.put(state, type, queue)}
  end

  defp queue_pop(q) do
    case :queue.out(q) do
      {{:value, item}, queue} -> {some(item), queue}
      {:empty, queue} -> {none(), queue}
    end
  end

  # Increments and wraps up task counter tag
  defp inc_task_counter(state) do
    counter = rem(state.task_counter + 1, @max_queue + @max_workers)
    %{state | task_counter: counter}
  end

  # Lookup task in working tasks list to confirm completion
  defp lookup_task(state, %Task{tag: tag}, from) do
    if task = Enum.find(state.working_tasks, & &1.tag == tag && &1.worker == from) do
      {some(task), %{state | working_tasks: List.delete(state.working_tasks, task)}}
    else
      {none(), state}
    end
  end
  defp lookup_task(state, _, _), do: {none(), state}
end
