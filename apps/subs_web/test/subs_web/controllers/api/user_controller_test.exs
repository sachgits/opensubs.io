defmodule SubsWeb.Test.Controllers.UserControllerTest do
  use SubsWeb.ConnCase
  use Bamboo.Test
  import Subs.Test.Support.Factory
  alias Subs.Test.Support.BCrypt
  alias Subs.UserRepo
  alias SubsWeb.Guardian
  alias SubsWeb.Helpers.UserHelper
  alias Subs.Helpers.DT

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/users" do
    test "when requesting without user params", %{conn: conn} do
      conn = post(conn, api_user_path(conn, :create))

      assert data = json_response(conn, 400)
      assert data["message"] == "Missing user params"
    end

    test "given empty user params", %{conn: conn} do
      conn = post(conn, api_user_path(conn, :create), user: %{})

      assert data = json_response(conn, 422)
      assert data["data"]["errors"] == %{
        "email" => ["can't be blank"],
        "password" => ["can't be blank"],
        "password_confirmation" => ["can't be blank"]
      }
    end

    test "given required user params", %{conn: conn} do
      email = "email@email.com"
      conn = post(conn, api_user_path(conn, :create), user: %{
        "email" => email,
        "password" => "password",
        "password_confirmation" => "password"
      })

      assert data = json_response(conn, 201)
      assert data["data"]["id"] != nil
      assert data["data"]["email"] == email
      assert data["data"]["confirmation_sent_at"] != nil
    end

    test "user created and confirmation email sent", %{conn: conn} do
      email = "email@email.com"

      conn = post(conn, api_user_path(conn, :create), user: %{
        "email" => email,
        "password" => "password",
        "password_confirmation" => "password"
      })

      assert data = json_response(conn, 201)

      user = UserRepo.get_by_id(data["data"]["id"])
      confirmation_url = UserHelper.generate_confirmation_url(user)
      confirmation_email = Notifier.Email.confirmation_email(email, %{
        confirmation_url: confirmation_url
      })

      assert_delivered_email(confirmation_email)
    end
  end

  describe "POST /api/users/authenticate" do
    setup %{conn: conn} do
      user_password = "password"

      user = insert(:user, encrypted_password: BCrypt.hashpwsalt(user_password))

      [conn: conn,
       user: user,
       user_password: user_password]
    end

    test "returns forbidden for missing credentials", %{conn: conn} do
      conn = post(conn, api_user_authenticate_path(conn, :authenticate))

      assert data = json_response(conn, 400)
      assert data["message"] == "Missing email and password"
    end

    test "returns forbidden for invalid credentials", %{conn: conn} do
      conn = post(conn, api_user_authenticate_path(conn, :authenticate), %{
        email: "unknown@email.com",
        password: "password"
      })

      assert data = json_response(conn, 403)
      assert data["message"] == "Invalid credentials"
    end

    test "authenticates user and returns auth_token",
         %{conn: conn, user: user, user_password: user_password} do
      conn = post(conn, api_user_authenticate_path(conn, :authenticate), %{
        "email" => user.email,
        "password" => user_password
      })

      assert data = json_response(conn, 200)

      {:ok, claims} = Guardian.decode_and_verify(data["meta"]["auth_token"])

      assert claims["sub"] == Integer.to_string(user.id)
    end

    test "authenticates user and returns user data",
         %{conn: conn, user: user, user_password: user_password} do
      conn = post(conn, api_user_authenticate_path(conn, :authenticate), %{
        "email" => user.email,
        "password" => user_password
      })

      assert data = json_response(conn, 200)
      assert data["data"] == %{
        "id" => user.id,
        "name" => user.name,
        "email" => user.email
      }
    end
  end

  describe "POST /api/users/confirm" do
    setup %{conn: conn} do
      user = insert(:user, %{confirmation_sent_at: NaiveDateTime.utc_now()})

      [conn: conn, user: user]
    end

    test "returns bad request for missing token", %{conn: conn} do
      conn = post(conn, api_user_confirm_path(conn, :confirm))

      assert data = json_response(conn, 400)
      assert data["message"] == "Missing token param"
    end

    test "returns forbidden for invalid token", %{conn: conn} do
      conn = post(conn, api_user_confirm_path(conn, :confirm), %{
        "t" => "invalid"
      })

      assert data = json_response(conn, 403)
      assert data["message"] == "Invalid token"
    end

    test "returns conflict for user confirmed", %{conn: conn, user: user} do
      {:ok, user} = UserRepo.update(user, %{confirmed_at: NaiveDateTime.utc_now()})

      conn = post(conn, api_user_confirm_path(conn, :confirm), %{
        "t" => user.confirmation_token
      })

      assert data = json_response(conn, 409)
      assert data["message"] == "User already confirmed"
    end

    test "confirms user account", %{conn: conn, user: user} do
      conn = post(conn, api_user_confirm_path(conn, :confirm), %{
        "t" => user.confirmation_token
      })

      assert data = json_response(conn, 202)
      assert data["data"] == %{
        "id" => user.id,
        "name" => user.name,
        "email" => user.email
      }
    end
  end

  describe "POST /api/users/recover_password" do
    setup %{conn: conn} do
      user = insert(:user, %{
        email: "dc@example.com",
        password_recovery_token: nil,
        password_recovery_expires_at: nil
      })

      [conn: conn, user: user]
    end

    test "returns ok when email to recover exists", %{conn: conn} do
      conn = post(conn, api_user_recover_password_path(conn, :recover_password), %{
        "email" => "dc@example.com"
      })

      # Assert default response is returned
      assert data = json_response(conn, 202)
      assert data["message"] == "A recover password email is on the way"

      user = UserRepo.get_by_email("dc@example.com")

      # Assert user password recovery data is reset
      assert user.password_recovery_expires_at != nil
      assert Timex.diff(user.password_recovery_expires_at, DT.now(), :minutes) == 59
      assert user.encrypted_password_recovery_token != nil

      # Assert recover email was delivered
      assert_delivered_with(subject: "Reset your Subs password")
    end

    test "returns ok when email to recover does not exist", %{conn: conn} do
      conn = post(conn, api_user_recover_password_path(conn, :recover_password), %{
        "email" => "jonjones@example.com"
      })

      assert data = json_response(conn, 202)
      assert data["message"] == "A recover password email is on the way"
    end

    test "returns unprocessable entity when sending an empty email param",
         %{conn: conn} do
      conn = post(
        conn,
        api_user_recover_password_path(conn, :recover_password)
      )

      assert data = json_response(conn, 400)
      assert data["message"] == "Missing emails param"
    end

    test "returns unprocessable entity when sending an invalid email param",
         %{conn: conn} do
      conn = post(
        conn,
        api_user_recover_password_path(conn, :recover_password),
        %{"email" => "invalid@"}
      )

      assert data = json_response(conn, 422)
      assert data["data"]["errors"] == %{
        "email" => ["has invalid format"]
      }
    end
  end
end

