defmodule ElixirNawalaDK168.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias ElixirNawalaDK168.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ElixirNawalaDK168.DataCase
    end
  end

  setup tags do
    ElixirNawalaDK168.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ElixirNawalaDK168.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end

