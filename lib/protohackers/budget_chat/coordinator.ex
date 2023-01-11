defmodule Protohackers.BudgetChat.Coordinator do
  alias Protohackers.BudgetChat.{Coordinator, Acceptor}
  use GenServer
  alias __MODULE__
  defstruct [:listen_socket, :client_pool_supervisor, :members]

  def start_link(arg) do
    GenServer.start_link(Coordinator, arg)
  end

  @impl true
  def init(_arg) do
    {:ok, sock} = :gen_tcp.listen(9996, [:inet6, :binary, active: true, packet: :line, reuseaddr: true])
    IO.puts("Listening on 9996")
    {:ok, %Coordinator{listen_socket: sock, members: %{} }, {:continue, :add_initial_acceptor}}
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

  @impl true
  def handle_call({:join, username}, {caller_pid, _tag}, state) do
    case Map.put_new(state.members, username, caller_pid) do
      new_members = %{^username => ^caller_pid} ->
        Process.monitor(caller_pid)
        broadcast_join(new_members, caller_pid, username)
        {:reply, {:ok, Map.keys(state.members)}, %Coordinator{state | members: new_members}}
      %{^username => _existing_user_pid} ->
        {:reply, {:error, :already_in_use}, state}
    end
  end

  @impl true
  def handle_call({:new_message, username, message}, {caller_pid, _tag}, state) do
    broadcast_message(state.members, caller_pid, username, message)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, _mref, :process, pid, _reason}, state) do
    {username, _cpid} = Enum.find(state.members, fn {_username, client_pid} -> client_pid == pid end)
    new_members = Map.drop(state.members, [username])
    for member_pid <- Map.values(new_members), do: Acceptor.leave(member_pid, username)

    {:noreply, %Coordinator{state | members: new_members}}
  end

  def new_message(pid, username, message) do
    GenServer.call(pid, {:new_message, username, message})
  end

  def add_acceptor(pid) do
    GenServer.cast(pid, :add_acceptor)
  end

  def join(pid, username) do
    GenServer.call(pid, {:join, username})
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

  defp broadcast_message(members, except_pid, username, message) do
    for member_pid <- Map.values(members), except_pid != member_pid, do: Acceptor.receive_message(member_pid, username, message)
  end

  defp broadcast_join(members, except_pid, new_username) do
    for member_pid <- Map.values(members), except_pid != member_pid, do: Acceptor.join(member_pid, new_username)
  end
end
