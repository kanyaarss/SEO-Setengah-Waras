defmodule ElixirNawalaDK168Web.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ElixirNawalaDK168Web.Endpoint

      use Phoenix.VerifiedRoutes,
        endpoint: ElixirNawalaDK168Web.Endpoint,
        router: ElixirNawalaDK168Web.Router,
        statics: ElixirNawalaDK168Web.static_paths()

      import Plug.Conn
      import Phoenix.ConnTest
      import ElixirNawalaDK168Web.ConnCase
    end
  end

  setup tags do
    ElixirNawalaDK168.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
