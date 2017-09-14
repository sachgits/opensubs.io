defmodule SubsWeb.Api.UserController do
  use SubsWeb, :controller
  alias Subs.UseCases.Users.{AuthenticateUser, CreateUser, ConfirmUser}
  alias Subs.Application.SendConfirmationEmail
  alias SubsWeb.Api.{ErrorView, ChangesetView}
  alias SubsWeb.Helpers.UserHelper

  def authenticate(conn, %{"email" => email, "password" => password}) do
    case AuthenticateUser.perform(email, password) do
      {:ok, %{user: user, auth_token: auth_token}} ->
        conn
        |> put_status(:ok)
        |> render("authenticate.json", user: user, auth_token: auth_token)
      {:error, {:invalid_credentials, _}} ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403", message: "Invalid credentials")
    end
  end
  def authenticate(conn, _) do
    conn
    |> put_status(:bad_request)
    |> render(ErrorView, :"400", message: "Missing email and password")
  end

  def create(conn, %{"user" => user_params}) do
    case CreateUser.perform(user_params) do
      {:ok, %{user: user}} ->
        confirmation_url = UserHelper.generate_confirmation_url(user)
        {:ok, user} = SendConfirmationEmail.send(user, confirmation_url)

        conn
        |> put_status(:created)
        |> render("create.json", user: user)
      {:error, {:invalid_params, %{changeset: changeset}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ChangesetView, "error.json", changeset: changeset)
    end
  end
  def create(conn, _) do
    conn
    |> put_status(:bad_request)
    |> render(ErrorView, :"400", message: "Missing user params")
  end

  def confirm(conn, %{"t" => token}) do
    case ConfirmUser.perform(token) do
      {:ok, %{user: user}} ->
        conn
        |> put_status(:accepted)
        |> render("confirm.json", user: user)
      {:error, {:invalid_token, _}} ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403", message: "Invalid token")
      {:error, {:user_confirmed, _}} ->
        conn
        |> put_status(:conflict)
        |> render(ErrorView, :"409", message: "User already confirmed")
      {:error, _} ->
        conn
        |> put_status(:conflict)
        |> render(ErrorView, :"500", message: "Something went wrong")
    end
  end
  def confirm(conn, _) do
    conn
      |> put_status(:bad_request)
      |> render(ErrorView, :"400", message: "Missing token param")
  end
end