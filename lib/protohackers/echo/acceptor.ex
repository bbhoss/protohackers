defmodule Protohackers.Echo.Acceptor do
  defstruct [:listen_socket, :client_socket, :coordinator, :received_bin]
  alias Protohackers.Echo.Coordinator
  alias __MODULE__
  use GenServer, restart: :temporary

  def start_link({lsock, coodinator}) do
    GenServer.start_link(Acceptor, {lsock, coodinator})
  end

  @impl GenServer
  def init({lsock, coordinator}) do
    {:ok, %Acceptor{listen_socket: lsock, coordinator: coordinator, received_bin: ""}, {:continue, :accept}}
  end

  @impl GenServer
  def handle_continue(:accept, state) do
    {:ok, csock} = acceptor(state.listen_socket)
    :ok = Coordinator.add_acceptor(state.coordinator)
    {:noreply, %Acceptor{state | client_socket: csock}}
  end

  @impl GenServer
  def handle_info({:tcp, _csock, client_bin}, state) do
    {:noreply, %Acceptor{state| received_bin: state.received_bin <> client_bin}}
  end

  @impl GenServer
  def handle_info({:tcp_closed, csock}, s = %Acceptor{client_socket: scsock}) when csock == scsock do
    IO.puts("Received disconnect from #{inspect(csock)}, echoing binary and exiting normally")
    :ok = :gen_tcp.send(csock, s.received_bin)
    :gen_tcp.close(csock)
    {:stop, :shutdown, s}
  end

  defp acceptor(lsock) do
    case :gen_tcp.accept(lsock) do
      {:ok, csock} ->
        IO.puts("Accepted client connection: #{inspect(csock)}")
        {:ok, csock}
      {:error, _} = err ->
        IO.puts("Unexpected error accepting: #{inspect(err)}")
        acceptor(lsock)
    end
  end
end
