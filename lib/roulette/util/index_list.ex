defmodule Roulette.Util.IndexList do

  def new(0), do: raise "must not come here"
  def new(1), do: [0]
  def new(len), do: (0..(len - 1)) |> Enum.to_list()

end
