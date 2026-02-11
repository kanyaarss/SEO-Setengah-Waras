defmodule ElixirNawalaDK168.Accounts do
  import Ecto.Query, warn: false
  alias ElixirNawalaDK168.Repo
  alias ElixirNawalaDK168.Accounts.Admin

  def get_admin!(id), do: Repo.get!(Admin, id)
  def get_admin(id), do: Repo.get(Admin, id)

  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(Admin, email: email)
  end

  def register_admin(attrs), do: %Admin{} |> Admin.registration_changeset(attrs) |> Repo.insert()

  def authenticate_admin(email, password) when is_binary(email) and is_binary(password) do
    case get_admin_by_email(email) do
      %Admin{} = admin ->
        if Pbkdf2.verify_pass(password, admin.password_hash), do: {:ok, admin}, else: :error

      _ ->
        Pbkdf2.no_user_verify()
        :error
    end
  end
end

