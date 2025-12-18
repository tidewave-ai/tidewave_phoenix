defmodule SampleAppWeb.UserLive.Index do
  @moduledoc false
  use Phoenix.LiveView

  on_mount {SampleAppWeb.Hooks.Auth, :require_user}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:users, list_users())
     |> assign(:filter, nil)
     |> assign_new(:page_title, fn -> "Users" end)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :filter, params["filter"])}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case create_user(user_params) do
      {:ok, _user} ->
        {:noreply, socket |> put_flash(:info, "User created")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete", %{"id" => _id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user_updated, _user}, socket) do
    {:noreply, socket}
  end

  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, :users, list_users())}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Users</h1>
      <ul>
        <li :for={user <- @users}>{user.name}</li>
      </ul>
    </div>
    """
  end

  defp list_users, do: []
  defp create_user(_params), do: {:ok, %{}}
end

defmodule SampleAppWeb.Hooks.Auth do
  @moduledoc false
  import Phoenix.Component

  def on_mount(:require_user, _params, session, socket) do
    socket =
      socket
      |> assign(:current_user, session["user"])
      |> assign(:authenticated, true)

    {:cont, socket}
  end

  def on_mount(:optional_user, _params, session, socket) do
    {:cont, assign(socket, :current_user, session["user"])}
  end
end

defmodule SampleAppWeb.SimpleLive do
  @moduledoc false
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def render(assigns) do
    ~H"""
    <div>Count: {@count}</div>
    """
  end
end
