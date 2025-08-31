defmodule MoeRisingWeb.PageController do
  use MoeRisingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
