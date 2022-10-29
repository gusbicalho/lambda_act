defmodule ASTTest do
  use ExUnit.Case
  doctest AST

  test "greets the world" do
    assert AST.hello() == :world
  end
end
