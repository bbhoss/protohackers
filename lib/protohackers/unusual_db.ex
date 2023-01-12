defmodule Protohackers.UnusualDB do
  use GenServer
  alias __MODULE__
  require Logger

  def start_link(arg) do
    GenServer.start_link(UnusualDB, arg)
  end

  @impl GenServer
  def init(_arg) do
    {:ok, bind_ip} = :inet_parse.address('2600:4041:586d:bf00:d8d5:5efa:d973:edee')
    {:ok, _socket} = :gen_udp.open(9995, [:binary, :inet6, active: true, ip: bind_ip])

    Logger.info("Listening for UDP on 9995")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info({:udp, socket, src_ip, src_port, data}, state) do
    Logger.debug("RX #{inspect(src_ip)}:#{src_port} #{inspect(data)}")
    new_state = process_message(state, socket, {src_ip, src_port}, data)
    {:noreply, new_state}
  end

  defp process_message(state, socket, destination, "version") do
    send_response(socket, destination, "version=Swagged Out Shiny KV Store 1.0")
    state
  end
  defp process_message(state, _socket, _destination, "version=" <> _value) do
    state
  end
  defp process_message(state, socket, destination, message) do
    # message = String.trim_trailing(message, "\n")
    case String.split(message, "=", parts: 2) do
      [key, value] ->
        Map.put(state, key, value)
      [request_key] ->
        send_response(socket, destination, request_key, Map.get(state, request_key, ""))
        state
    end
  end

  defp send_response(socket, destination, key, value) do
    response = Enum.join([key, value], "=")
    send_response(socket, destination, response)
  end

  defp send_response(socket, destination, msg) do
    Logger.debug("TX: #{inspect(msg)}")
    :ok = :gen_udp.send(socket, destination, msg)
  end


end
