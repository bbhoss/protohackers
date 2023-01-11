defmodule Protohackers.BudgetChat.Supervisor do
  use Supervisor
  alias __MODULE__, as: BCSupervisor
  alias Protohackers.BudgetChat.Coordinator

  def start_link(arg) do
    Supervisor.start_link(BCSupervisor, arg, [])
  end

  @impl true
  def init(_arg) do
    children = [
      DynamicSupervisor,
      Coordinator
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
