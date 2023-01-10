defmodule Protohackers.Means.Supervisor do
  use Supervisor
  alias __MODULE__, as: MSupervisor
  alias Protohackers.Means.Coordinator

  def start_link(arg) do
    Supervisor.start_link(MSupervisor, arg, [])
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
