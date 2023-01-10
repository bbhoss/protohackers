defmodule Protohackers.Means.Acceptor do
  defstruct [:listen_socket, :client_socket, :coordinator, :received_bin, :inserts]
  alias Protohackers.Means.{Coordinator, Parser}
  alias Protohackers.Means.Packets.{Insert, Query}
  alias __MODULE__
  require Logger
  use GenServer, restart: :temporary

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
    :ok = Coordinator.add_acceptor(state.coordinator)
    Logger.metadata(client_socket: inspect(csock))
    {:noreply, %Acceptor{state | client_socket: csock, inserts: []}}
  end

  @impl GenServer
  def handle_info({:tcp, _csock, client_bin}, state) do
    Logger.debug("RX Request: #{inspect(client_bin)}")
    combined_bins = [state.received_bin, client_bin]
    if IO.iodata_length(combined_bins) >= 9 do
      parse_and_respond(combined_bins, state)
    else
      # Wait for more
      {:noreply, %Acceptor{state | received_bin: combined_bins}}
    end
  end

  @impl GenServer
  def handle_info({:tcp_closed, csock}, s = %Acceptor{client_socket: scsock}) when csock == scsock do
    Logger.debug("Received disconnect from #{inspect(csock)} exiting normally")
    {:stop, :shutdown, s}
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

  defp parse_and_respond(client_bin, state) do
    with {:ok, requests, remaining_bin} <- Parser.parse_packets(client_bin),
         :ok = Logger.debug("Processing requests: #{inspect(requests)}"),
         {:ok, new_state} <- handle_requests(requests, %Acceptor{state | received_bin: [remaining_bin]}) do
           {:noreply, new_state}
         else
            {:error, err} ->
              Logger.debug("Error handling requests: #{inspect(err)}")
              error_response(state.client_socket, "Error processing requests")
              {:stop, :shutdown, state}
         end
  end

  defp handle_requests([], state), do: {:ok, state}
  defp handle_requests([i=%Insert{} | tail_requests], state) do
    handle_requests(tail_requests, %Acceptor{state | inserts: [i | state.inserts]})
  end
  defp handle_requests([q=%Query{} | tail_requests], state) do
    send_response(state.client_socket, query_result(q, state.inserts))
    handle_requests(tail_requests, state)
  end

  defp error_response(csock, error_message) do
    send_response(csock, error_message)
    close_connection(csock)
  end

  defp send_response(sock, response) do
    Logger.debug("Sending response: #{inspect(response)}")
    :gen_tcp.send(sock, response)
  end

  defp close_connection(sock) do
    :gen_tcp.close(sock)
  end

  defp query_result(%Query{mintime: mintime, maxtime: maxtime}, _inserts) when mintime > maxtime, do: <<0::big-signed-integer-32>>
  defp query_result(q=%Query{mintime: mintime, maxtime: maxtime}, inserts) do
    Logger.debug("Received Query: #{inspect(q)} over Inserts: #{inspect(inserts)}")
    {running_sum, count} = for %Insert{timestamp: ts, price: price} <- inserts, ts in mintime..maxtime, reduce: {0,0} do
      {running_sum, count} -> {running_sum+price, count+1}
    end

    average = if count > 0 do
      round(running_sum/count)
    else
      0
    end
    <<average::big-signed-integer-32>>
  end
end
