defmodule BubblegumNifsTest do
  use ExUnit.Case
  doctest BubblegumNifs

  test "greets the world" do
    assert BubblegumNifs.hello() == :world
  end
end
