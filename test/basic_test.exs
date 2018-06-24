defmodule Roulette.Test.BasicTest do

  use ExUnit.Case, async: false

  alias Roulette.Test.Session1

  test "basic pubsub" do

    {:ok, s1} = Session1.start_link(:s1)
    {:ok, s2} = Session1.start_link(:s2)

    assert Session1.stack(s1) |> Enum.empty? == true
    assert Session1.stack(s2) |> Enum.empty? == true

    Session1.sub(s1, "t1")
    Process.sleep(20)

    Session1.pub(s2, "t1", "foobar")
    Process.sleep(20)

    assert Session1.stack(s1) == [{"t1", "foobar"}]
    assert Session1.stack(s2) |> Enum.empty? == true

    # ONE MORE
    Session1.pub(s2, "t1", "barbuz")
    Process.sleep(20)

    assert Session1.stack(s1) == [{"t1", "barbuz"},{"t1", "foobar"}]
    assert Session1.stack(s2) |> Enum.empty? == true

    require Logger

    # UNSUB
    Session1.unsub(s1, "t1")
    Process.sleep(20)

    # ONE MORE
    Session1.pub(s2, "t1", "buzfoo")
    Process.sleep(20)

    # same as last time
    assert Session1.stack(s1) == [{"t1", "barbuz"},{"t1", "foobar"}]
    assert Session1.stack(s2) |> Enum.empty? == true

  end

end
