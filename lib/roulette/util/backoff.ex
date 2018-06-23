defmodule Roulette.Util.Backoff do

  alias Roulette.Config

  def calc(module, type, attempts) do
    base = Config.get(module, type, :base_backoff)
    max  = Config.get(module, type, :max_backoff)
    do_calc(base, max, attempts)
  end

  defp do_calc(base_ms, max_ms, attempts) do
    base_ms * :math.pow(2, attempts)
    |> min(max_ms)
    |> trunc
    |> :rand.uniform
  end

end
