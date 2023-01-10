defmodule Protohackers.Primetime.Acceptor do
  defstruct [:listen_socket, :client_socket, :coordinator, :received_bin]
  alias Protohackers.Primetime.Coordinator
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
  def handle_info({:tcp, csock, client_bin}, state) do
    IO.inspect(client_bin, label: "RX request")
    combined_bins = state.received_bin <> client_bin
    if String.ends_with?(combined_bins, "\n") do
      parse_and_respond(csock, combined_bins, state)
    else
      # Wait for more
      {:noreply, %Acceptor{state | received_bin: combined_bins}}
    end
  end

  @impl GenServer
  def handle_info({:tcp_closed, csock}, s = %Acceptor{client_socket: scsock}) when csock == scsock do
    IO.puts("Received disconnect from #{inspect(csock)} exiting normally")
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

  defp parse_and_respond(csock, client_bin, state) do
    state = %Acceptor{state | received_bin: ""}
    case Jason.decode(client_bin) do
      {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
        IO.inspect(number, label: "Number: ")
        send_response(csock, %{"method" => "isPrime", "prime" => is_prime?(number)})
        {:noreply, state}
      {:ok, %{"method" => "isPrime", "number" => _nonnumber}} ->
        error_response(csock, "invalid parameter")
        {:stop, :shutdown, state}
      {:ok, %{"method" => method}} ->
        error_response(csock, "no method #{inspect(method)}")
        {:stop, :shutdown, state}
      _else ->
        error_response(csock, "error parsing json")
        {:stop, :shutdown, state}
    end
  end

  defp error_response(csock, error_message) do
    send_response(csock, %{error: error_message})
    close_connection(csock)
  end

  defp send_response(sock, response) do
    IO.inspect(response, label: "Sending response")
    :gen_tcp.send(sock, Jason.encode!(response) <> "\n")
  end

  defp close_connection(sock) do
    :gen_tcp.close(sock)
  end

  def is_prime?(2), do: true
  def is_prime?(n) when is_float(n), do: false
  def is_prime?(n) when n<2 or rem(n,2) == 0, do: false
  def is_prime?(n), do: is_prime?(n,3)

  def is_prime?(n,k) when n<k*k, do: true
  def is_prime?(n,k) when rem(n,k)==0, do: false
  def is_prime?(n,k), do: is_prime?(n,k+2)
end
