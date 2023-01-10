defmodule Protohackers.Primetime.Supervisor do
  use Supervisor
  alias __MODULE__, as: PTSupervisor
  alias Protohackers.Primetime.Coordinator

  def start_link(arg) do
    Supervisor.start_link(PTSupervisor, arg, [])
  end

  @impl true
  def init(_arg) do
    children = [
      DynamicSupervisor,
      Coordinator
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
