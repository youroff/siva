defmodule Siva.Scaler do
  import MonEx.{Result, Option}
  alias Siva.Worker
  require Logger

  @interval Application.get_env(:siva, :scale_interval)
  @scale_up Application.get_env(:siva, :scale_up)
  @scale_down Application.get_env(:siva, :scale_down)
  @delay Application.get_env(:siva, :scale_delay)

  def start_link(coordinator) do
    GenServer.start_link __MODULE__, coordinator
  end

  def init(coordinator) do
    Process.send_after self(), :scale, @interval
    Worker.start(coordinator)
    ok(%{
      coordinator: coordinator,
      tasks: 0,
      workers: 0,
      last_scaled: 0
    })
  end

  # Recurrent scale procedure, launches scaling if conditions met
  def handle_info(:scale, state) do
    {tasks, workers} = GenServer.call(state.coordinator, :stats)
    state = %{state | tasks: approx(state.tasks, tasks), workers: approx(state.workers, workers)}
    state = scale(state)
    |> MonEx.map(& %{state | last_scaled: &1})
    |> get_or_else(state)
    Process.send_after self(), :scale, @interval
    {:noreply, state}
  end

  # Jacobson approximation
  defp approx(prev, next) do
    0.9 * prev + 0.1 * next
  end

  # Scale routine
  defp scale(s) do
    cond do
      will_scale_up(s) ->
        Worker.start(s.coordinator)
        some(System.system_time(:milliseconds))
      will_scale_down(s) ->
        GenServer.call(s.coordinator, :release_worker)
        |> MonEx.map(fn w ->
          GenServer.stop(w)
          System.system_time(:milliseconds)
        end)
      true -> none()
    end
  end

  # Basic condition for scaling that it happend at least @delay milliseconds ago
  defp can_scale(%{last_scaled: timestamp}) do
    timestamp + @delay < System.system_time(:milliseconds)
  end

  # Is there more than @scale_up tasks in the queue?
  defp will_scale_up(%{tasks: tasks} = s) do
    can_scale(s) && tasks >= @scale_up
  end

  # Is there more than @scale_down workers waiting?
  defp will_scale_down(%{workers: workers} = s) do
    can_scale(s) && workers >= @scale_down
  end
end
