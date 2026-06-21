defmodule GinTest do
  use ExUnit.Case
  doctest Gin

  test "greets the world" do
    assert Gin.hello() == :world
  end
end
