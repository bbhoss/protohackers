defmodule Protohackers.Means.ParserTest do
  use ExUnit.Case
  alias Protohackers.Means.Parser
  alias Protohackers.Means.Packets.{Insert, Query}

  test "parse_packets/1 parses packets from iolist and returns a list of packet structs" do
    insert_packet = << 0x49, 0, 0, 0x30, 0x39, 0, 0, 0, 0x65 >>
    negative_insert_packet = << 0x49, 0, 0, 0x30, 0x39, 190, 227, 225, 106 >>
    query_packet = << 0x51, 0, 0, 0x03, 0xE8, 0, 0x01, 0x86, 0xA0 >>
    assert Parser.parse_packets([insert_packet, negative_insert_packet, query_packet]) ==
      {:ok, [
          %Insert{timestamp: 12345, price: 101},
          %Insert{timestamp: 12345, price: -1092361878},
          %Query{mintime: 1000, maxtime: 100000},
        ],
        ""
      }
  end

  test "parse_packets/1 parses packets from partial iolist and returns a list of packet structs with remaining binary" do
    insert_packet = << 0x49, 0, 0, 0x30, 0x39, 0, 0, 0, 0x65 >>
    query_packet = << 0x51, 0, 0, 0x03, 0xE8, 0, 0x01, 0x86, 0xA0 >>
    partial_query_packet = << 0x51, 0, 0, 0x03, 0xE8, 0, 0x01 >>
    assert Parser.parse_packets([insert_packet, query_packet, partial_query_packet]) ==
      {:ok, [
          %Insert{timestamp: 12345, price: 101},
          %Query{mintime: 1000, maxtime: 100000},
        ],
        partial_query_packet
      }
  end
end
