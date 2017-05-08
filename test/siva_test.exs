defmodule SivaTest do
  use ExUnit.Case
  doctest Siva

  test "the truth" do
    Enum.each 0..10, fn i ->
      GenServer.call(Siva, {:enqueue, {:*, 2, i}})
    end

    :timer.sleep(60000)
  end
end
