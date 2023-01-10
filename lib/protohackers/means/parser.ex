defmodule Protohackers.Means.Parser do
  alias __MODULE__
  alias Protohackers.Means.Packets.{Insert, Query}
  def parse_packets(packets) when is_list(packets), do: IO.iodata_to_binary(packets) |> Parser.parse_packets()

  def parse_packets(bin, accumulator \\ [])
  def parse_packets(bin, accumulator) when is_binary(bin) and byte_size(bin) < 9, do: {:ok, Enum.reverse(accumulator), bin}
  def parse_packets(<<0x49, timestamp::big-signed-integer-32, price::big-signed-integer-32, rest::binary>>, accumulator) do
    insert = %Insert{timestamp: timestamp, price: price}
    parse_packets(rest, [insert | accumulator])
  end
  def parse_packets(<<0x51, mintime::big-signed-integer-32, maxtime::big-signed-integer-32, rest::binary>>, accumulator) do
    query = %Query{mintime: mintime, maxtime: maxtime}
    parse_packets(rest, [query | accumulator])
  end
  def parse_packets(bin, _accumulator) when is_binary(bin), do: {:error, "Invalid packet"}
end
