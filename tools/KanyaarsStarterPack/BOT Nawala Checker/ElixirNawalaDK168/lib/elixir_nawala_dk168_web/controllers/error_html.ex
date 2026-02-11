defmodule ElixirNawalaDK168Web.ErrorHTML do
  use ElixirNawalaDK168Web, :html

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end

