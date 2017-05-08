defmodule Siva.Task do
  defstruct tag: 0,
    payload: nil,
    worker: nil,
    owner: nil,
    result: nil
end
