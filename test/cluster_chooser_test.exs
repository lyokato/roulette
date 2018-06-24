defmodule Roulette.Test.ClusterChooserTest do

  use ExUnit.Case, async: true

  alias Roulette.ClusterChooser

  test "cluster chooser" do

    ClusterChooser.init(Foobar, [
      "192.168.0.2",
      "192.168.0.3",
      "192.168.0.4",
    ])

    ClusterChooser.init(Barbuz, [
      "192.168.0.5",
      "192.168.0.6",
      "192.168.0.7",
    ])

    assert ClusterChooser.choose(Foobar, "topic1") == "192.168.0.2"
    assert ClusterChooser.choose(Foobar, "topic2") == "192.168.0.4"
    assert ClusterChooser.choose(Foobar, "topic3") == "192.168.0.4"
    assert ClusterChooser.choose(Foobar, "topic4") == "192.168.0.3"
    assert ClusterChooser.choose(Foobar, "topic5") == "192.168.0.3"
    assert ClusterChooser.choose(Foobar, "topic6") == "192.168.0.3"
    assert ClusterChooser.choose(Foobar, "topic7") == "192.168.0.2"

    assert ClusterChooser.choose(Barbuz, "topic1") == "192.168.0.5"
    assert ClusterChooser.choose(Barbuz, "topic2") == "192.168.0.7"
    assert ClusterChooser.choose(Barbuz, "topic3") == "192.168.0.7"
    assert ClusterChooser.choose(Barbuz, "topic4") == "192.168.0.6"
    assert ClusterChooser.choose(Barbuz, "topic5") == "192.168.0.6"
    assert ClusterChooser.choose(Barbuz, "topic6") == "192.168.0.6"
    assert ClusterChooser.choose(Barbuz, "topic7") == "192.168.0.5"

  end


end
