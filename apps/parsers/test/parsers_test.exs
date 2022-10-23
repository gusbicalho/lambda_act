defmodule ParsersTest do
  use ExUnit.Case
  doctest Parsers

  test "greets the world" do
    assert Parsers.hello() == :world
  end
end
