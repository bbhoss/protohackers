defmodule Protohackers.Echo.Coordinator do
  alias Protohackers.Echo.{Coordinator, Acceptor}
  use GenServer
  alias __MODULE__
  defstruct [:listen_socket, :client_pool_supervisor]

  def start_link(arg) do
    GenServer.start_link(Coordinator, arg)
  end

  @impl true
  def init(_arg) do
    {:ok, sock} = :gen_tcp.listen(9999, [:inet6, :binary, active: true, packet: :raw, exit_on_close: false])
    IO.puts("Listening on 9999")
    {:ok, %Coordinator{listen_socket: sock}, {:continue, :add_initial_acceptor}}
  end

  @impl true
  def handle_continue(:add_initial_acceptor, state) do
    client_pool_supervisor = locate_child_pool_supervisor()
    do_add_acceptor(client_pool_supervisor, state.listen_socket)
    {:noreply, %Coordinator{state | client_pool_supervisor: client_pool_supervisor}}
  end

  @impl true
  def handle_cast(:add_acceptor, state) do
    do_add_acceptor(state.client_pool_supervisor, state.listen_socket)
    {:noreply, state}
  end

  def add_acceptor(pid) do
    GenServer.cast(pid, :add_acceptor)
  end

  defp do_add_acceptor(client_pool_supervisor, listen_socket) do
    {:ok, child} = DynamicSupervisor.start_child(client_pool_supervisor, {Acceptor, {listen_socket, self()}})
    IO.inspect(child, label: "Started Acceptor Child")
    :ok
  end

  defp locate_child_pool_supervisor() do
    {:parent, supervisor} = :erlang.process_info(self(), :parent)
    [ds_child |_restchildren] = Supervisor.which_children(supervisor)
      |> Enum.reverse()

    case ds_child do
      {DynamicSupervisor, child_pid, :supervisor, [DynamicSupervisor]} when is_pid(child_pid) ->
        child_pid
    end
  end
end
