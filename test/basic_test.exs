defmodule Roulette.Test.Basic do

  use ExUnit.Case

  alias Roulette.Test.SubscriberServer

  test "basic pubsub" do

    {:ok, s1} = SubscriberServer.start_link(:s1)
    {:ok, s2} = SubscriberServer.start_link(:s2)

    assert SubscriberServer.stack(s1) |> Enum.empty? == true
    assert SubscriberServer.stack(s2) |> Enum.empty? == true

    SubscriberServer.sub(s1, "t1")
    Process.sleep(20)

    SubscriberServer.pub(s2, "t1", "foobar")
    Process.sleep(20)

    assert SubscriberServer.stack(s1) == [{"t1", "foobar"}]
    assert SubscriberServer.stack(s2) |> Enum.empty? == true

    # ONE MORE
    SubscriberServer.pub(s2, "t1", "barbuz")
    Process.sleep(20)

    assert SubscriberServer.stack(s1) == [{"t1", "barbuz"},{"t1", "foobar"}]
    assert SubscriberServer.stack(s2) |> Enum.empty? == true

    require Logger

    # UNSUB
    SubscriberServer.unsub(s1, "t1")
    Process.sleep(20)

    # ONE MORE
    SubscriberServer.pub(s2, "t1", "buzfoo")
    Process.sleep(20)

    # same as last time
    assert SubscriberServer.stack(s1) == [{"t1", "barbuz"},{"t1", "foobar"}]
    assert SubscriberServer.stack(s2) |> Enum.empty? == true

  end

end
