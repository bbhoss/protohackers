defmodule Protohackers.Echo.Supervisor do
  use Supervisor
  alias __MODULE__, as: ESupervisor
  alias Protohackers.Echo.Coordinator

  def start_link(arg) do
    Supervisor.start_link(ESupervisor, arg, [])
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
