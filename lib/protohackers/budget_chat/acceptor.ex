defmodule Protohackers.BudgetChat.Acceptor do
  defstruct [:listen_socket, :client_socket, :coordinator, :received_bin, :username]
  alias __MODULE__
  alias Protohackers.BudgetChat.Coordinator
  require Logger
  use GenServer, restart: :temporary
  @valid_username ~r/^[A-Za-z0-9]+$/

  def start_link({lsock, coodinator}) do
    GenServer.start_link(Acceptor, {lsock, coodinator})
  end

  @impl GenServer
  def init({lsock, coordinator}) do
    {:ok, %Acceptor{listen_socket: lsock, coordinator: coordinator, received_bin: []}, {:continue, :accept}}
  end

  @impl GenServer
  def handle_continue(:accept, state) do
    {:ok, csock} = acceptor(state.listen_socket)
    Logger.metadata(client_socket: inspect(csock))
    :ok = Coordinator.add_acceptor(state.coordinator)
    send_greeting(csock)
    {:noreply, %Acceptor{state | client_socket: csock}}
  end

  @impl GenServer
  def handle_info({:tcp, csock, client_bin}, state = %Acceptor{username: nil}) do
    log_rx(client_bin)
    username = String.trim(client_bin)
    if Regex.match?(@valid_username, username) do
      case Coordinator.join(state.coordinator, username) do
        {:ok, existing_members} ->
          send_response(csock, "* The room contains: #{Enum.join(existing_members, ", ")}")
          {:noreply, %Acceptor{state | username: username}}
        {:error, :already_in_use} ->
          error_response(csock, "* Username already in use")
          {:stop, :shutdown, state}
      end
    else
      error_response(csock, "* Invalid username")
      {:stop, :shutdown, state}
    end
  end

  @impl GenServer
  def handle_info({:tcp, _csock, client_bin}, state) do
    log_rx(client_bin)
    :ok = Coordinator.new_message(state.coordinator, state.username, String.trim(client_bin))
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:tcp_closed, csock}, s = %Acceptor{client_socket: scsock}) when csock == scsock do
    Logger.debug("Received disconnect from #{inspect(csock)} exiting normally")
    {:stop, :shutdown, s}
  end

  @impl true
  def handle_cast({:join, new_username}, state) do
    send_response(state.client_socket, "* #{new_username} has entered the room")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:leave, username}, state) do
    send_response(state.client_socket, "* #{username} has left the room")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:receive_message, username, message}, state) do
    send_response(state.client_socket, "[#{username}] #{message}")
    {:noreply, state}
  end

  def join(pid, new_username) do
    GenServer.cast(pid, {:join, new_username})
  end

  def leave(pid, username) do
    GenServer.cast(pid, {:leave, username})
  end

  def receive_message(pid, username, message) do
    GenServer.cast(pid, {:receive_message, username, message})
  end

  defp acceptor(lsock) do
    case :gen_tcp.accept(lsock) do
      {:ok, csock} ->
        Logger.debug("Accepted client connection: #{inspect(csock)}")
        {:ok, csock}
      {:error, _} = err ->
        Logger.debug("Unexpected error accepting: #{inspect(err)}")
        acceptor(lsock)
    end
  end

  defp error_response(csock, error_message) do
    send_response(csock, error_message)
    close_connection(csock)
  end

  defp send_greeting(csock) do
    send_response(csock, "Welcome to budgetchat! What shall I call you?")
  end

  defp send_response(sock, response) do
    Logger.debug("Sending response: #{inspect(response)}")
    :gen_tcp.send(sock, [response, "\n"])
  end

  defp close_connection(sock) do
    :gen_tcp.close(sock)
  end

  defp log_rx(rx_bin) do
    Logger.debug("RX: #{inspect(rx_bin)}")
  end
end
