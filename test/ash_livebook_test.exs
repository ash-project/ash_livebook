defmodule AshLivebookTest do
  use ExUnit.Case
  doctest AshLivebook

  test "greets the world" do
    assert AshLivebook.hello() == :world
  end
end
