defmodule Roulette.Test.HashRingTest do

  use ExUnit.Case, async: false

  alias Roulette.Test.Session2

  defp gen_topics(len, count) do
    for _idx <- (1..count) do
      len |> :crypto.strong_rand_bytes() |> Base.encode64 |> binary_part(0, len)
    end
  end

  test "hash ring" do

    {:ok, s1} = Session2.start_link(:s1)
    {:ok, s2} = Session2.start_link(:s2)

    assert Session2.stack(s1) |> Enum.empty? == true
    assert Session2.stack(s2) |> Enum.empty? == true

    topics = gen_topics(20, 20)

    Enum.each(topics, fn topic ->
      Session2.sub(s1, topic)
      Process.sleep(20)
    end)

    Enum.each(topics, fn topic ->
      Session2.pub(s2, topic, "foobar")
      Process.sleep(20)
    end)

    assert Session2.stack(s1) |> length == 20
    assert Session2.stack(s2) |> Enum.empty? == true

  end

end
