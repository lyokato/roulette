defmodule Roulette.Util.Backoff do

  alias Roulette.Config

  @type category :: :subscriber
                  | :publisher
                  | :connection

  @spec calc(module, category, non_neg_integer) :: pos_integer
  def calc(module, type, attempts) do
    base = Config.get(module, type, :base_backoff)
    max  = Config.get(module, type, :max_backoff)
    do_calc(base, max, attempts)
  end

  defp do_calc(base_ms, max_ms, attempts) do
    base = base_ms * :math.pow(2, attempts)
    base |> min(max_ms) |> trunc |> :rand.uniform
  end

end
