defmodule ExBanking.User do
  alias Helpers.SchemaValidator
  alias ExBanking.Repo
  # user_name is string and currency_account is a list of currency accounts
  defstruct [:user_name, :currency_accounts]

  @type t :: %__MODULE__{
          user_name: String.t(),
          currency_accounts: [String.t()]
        }

  @required_fields [:user_name]
  @table_name :users

  # cast will return empty struct if params is nil
  def cast(params \\ %{}) do
    params
    |> case do
      {:error, _} = error ->
        error

      params ->
        transient_map =
          Map.keys(%__MODULE__{})
          |> Enum.reject(&(&1 == :__struct__))
          |> Enum.map(fn key ->
            {key, Map.get(params, key) || Map.get(params, Atom.to_string(key))}
          end)
          |> Map.new()

        struct(__MODULE__, transient_map)
    end
  end

  def get(user_name) do
    %{user_name: user_name}
    |> SchemaValidator.validate_string(@required_fields)
    |> case do
      {:error, _} = error ->
        error

      params ->
        Repo.get(@table_name, params.user_name)
        |> case do
          {:ok, user} -> {:ok, cast(user)}
          {:error, _} -> {:error, :user_does_not_exist}
        end
    end
  end

  def insert(params) do
    params
    |> SchemaValidator.validate_required(@required_fields)
    |> SchemaValidator.validate_string(@required_fields)
    |> cast()
    |> SchemaValidator.validate_not_nil(@required_fields)
    |> case do
      {:ok, user} ->
        ExBanking.Repo.insert(@table_name, user.user_name, user)
        |> case do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, :user_already_exists}
        end

      {:error, _} = error ->
        error
    end
  end

  def update(params) do
    params
    |> SchemaValidator.validate_required(@required_fields)
    |> SchemaValidator.validate_string(@required_fields)
    |> cast()
    |> SchemaValidator.validate_not_nil(@required_fields)
    |> case do
      {:error, _} = error -> error
      {:ok, user} -> ExBanking.Repo.update(@table_name, user.user_name, user)
    end
  end

  def delete(user_name) do
    ExBanking.Repo.delete(@table_name, user_name)
    |> case do
      {:ok, _} -> {:ok, :user_deleted}
      {:error, _reason} -> {:error, :user_not_found}
    end
  end

  # helpers
  # I am not considering whitespaces..although it was not menthioned in the requirements
  @spec create_users([String.t()]) :: {:ok, [t()]}
  def create_users(users) do
    result =
      users
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn user_name ->
        user_name = String.trim(user_name)

        user_name
        |> String.length()
        |> Kernel.>(0)
        |> case do
          true ->
            insert(%{user_name: user_name, currency: "USD"})
            |> case do
              {:ok, user} -> user
              {:error, _} -> nil
            end

          false ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, result}
  end
end
