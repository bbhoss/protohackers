defmodule Protohackers.Means.Packets do
  defmodule Insert, do: defstruct [:timestamp, :price]
  defmodule Query, do: defstruct [:mintime, :maxtime]
end
