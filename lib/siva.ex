defmodule Siva do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [worker(Siva.Coordinator, [])]

    opts = [strategy: :one_for_one, name: Sms.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
