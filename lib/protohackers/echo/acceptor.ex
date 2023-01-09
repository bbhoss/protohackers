defmodule Protohackers.Echo.Acceptor do
  defstruct [:listen_socket, :client_socket, :coordinator]
  alias Protohackers.Echo.Coordinator
  alias __MODULE__
  use GenServer

  def start_link({lsock, coodinator}) do
    GenServer.start_link(Acceptor, {lsock, coodinator})
  end

  @impl GenServer
  def init({lsock, coordinator}) do
    {:ok, %Acceptor{listen_socket: lsock, coordinator: coordinator}, {:continue, :accept}}
  end

  @impl GenServer
  def handle_continue(:accept, state) do
    {:ok, csock} = acceptor(state.listen_socket)
    :ok = Coordinator.add_acceptor(state.coordinator)
    {:noreply, %Acceptor{state | client_socket: csock}}
  end

  @impl GenServer
  def handle_info({:tcp_closed, csock}, s = %Acceptor{client_socket: scsock}) when csock == scsock do
    IO.puts("Received disconnect from client, exiting normally")
    {:stop, :normal, s}
  end

  @impl GenServer
  def handle_info(msg, state) do
    IO.inspect(msg, label: "Inbound message received")
    {:noreply, state}
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
