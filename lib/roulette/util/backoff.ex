defmodule Roulette.Util.Backoff do

  alias Roulette.Config

  @spec calc(module, non_neg_integer) :: pos_integer
  def calc(module, attempts) do
    base = Config.get(module, :base_backoff)
    max  = Config.get(module, :max_backoff)
    do_calc(base, max, attempts)
  end

  defp do_calc(base_ms, max_ms, attempts) do
    base = base_ms * :math.pow(2, attempts)
    base |> min(max_ms) |> trunc |> :rand.uniform
  end

end
