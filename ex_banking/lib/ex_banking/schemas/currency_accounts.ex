defmodule ExBanking.CurrencyAccounts do
  alias Helpers.SchemaValidator

  defstruct [:name, :user_name, :balance]
  @type t :: %__MODULE__{name: String.t(), user_name: String.t(), balance: float()}

  alias ExBanking.Repo

  @table_name :currency_accounts
  @required_fields [:name, :user_name]

  def pre_validate(params) do
    params
    |> SchemaValidator.validate_required(@required_fields)
    |> SchemaValidator.validate_string(@required_fields)
    |> SchemaValidator.validate_number([:balance])
    |> SchemaValidator.validate_not_negative([:balance])
  end

  def post_validate(params) do
    params
    |> SchemaValidator.validate_not_nil(@required_fields)
  end

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

  def get(account_name, user_name) do
    key = generate_key(user_name, account_name)

    Repo.get(@table_name, key)
    |> case do
      {:ok, currency_account} -> {:ok, cast(currency_account)}
      {:error, _} -> {:error, :currency_account_not_found}
    end
  end

  def insert(params) do
    pre_validate(params)
    |> cast()
    |> post_validate()
    |> case do
      {:ok, currency_account} ->
        key = generate_key(currency_account.user_name, currency_account.name)

        Repo.insert(@table_name, key, currency_account)
        |> case do
          {:ok, currency_account} -> {:ok, currency_account}
          {:error, _} -> {:error, :currency_account_already_exists}
        end

      {:error, _} = error ->
        error
    end
  end

  def update(params) do
    pre_validate(params)
    |> cast()
    |> post_validate()
    |> case do
      {:error, _} = error ->
        error

      {:ok, currency_account} ->
        key = generate_key(currency_account.user_name, currency_account.name)
        Repo.update(@table_name, key, currency_account)
    end
  end

  def delete(name, user_name) do
    key = generate_key(user_name, name)
    Repo.delete(@table_name, key)
  end

  def get_all_user_accounts(user_name) do
    Repo.matching_list(@table_name, {:"$1", %{user_name: user_name}})
    |> case do
      {:ok, currency_accounts} ->
        currency_accounts
        |> Enum.map(fn currency_account ->
          Repo.get(@table_name, currency_account)
          |> case do
            {:ok, currency_account} -> cast(currency_account)
            {:error, _} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        {:error, :currency_accounts_not_found}
    end
  end

  defp generate_key(user_name, currency_account_name) do
    "#{user_name}_#{currency_account_name}"
  end
end
