defmodule Roulette.Util do

  def calc_backoff(base_ms, max_ms, attempt_counts) do
    base_ms * :math.pow(2, attempt_counts)
    |> min(max_ms)
    |> trunc
    |> :rand.uniform
  end

end
