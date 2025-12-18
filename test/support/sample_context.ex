defmodule SampleApp.Accounts do
  @moduledoc false

  @doc """
  Gets a user by ID.

  Raises if the user does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)
  """
  def get_user!(id) do
    # Implementation
    %{id: id}
  end

  @doc """
  Lists all users.

  Returns an empty list if no users exist.
  """
  def list_users do
    []
  end

  @doc """
  Creates a user with the given attributes.

  Returns `{:ok, user}` on success or `{:error, changeset}` on failure.
  """
  def create_user(attrs) do
    {:ok, Map.merge(%{id: 1}, attrs)}
  end

  @doc """
  Updates a user.
  """
  def update_user(user, attrs) do
    {:ok, Map.merge(user, attrs)}
  end

  @doc """
  Deletes a user.
  """
  def delete_user(user) do
    {:ok, user}
  end

  def change_user(user, attrs \\ %{}) do
    # Returns a changeset
    %{data: user, changes: attrs}
  end
end

defmodule SampleApp.Blog do
  @moduledoc false

  def list_posts do
    []
  end

  def get_post!(id) do
    %{id: id}
  end

  def create_post(attrs) do
    {:ok, attrs}
  end

  # Private function - should not appear in get_module_functions
  defp validate_post(_attrs), do: :ok
end
