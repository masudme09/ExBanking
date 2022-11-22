defmodule ExBanking.UserProcessors do
  @doc """
  This module is responsible for processing user requests.
  """
  import ExBanking.NumericOperations
  alias Helpers.SchemaValidator
  alias ExBanking.{User, CurrencyAccounts}

  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) do
    # create user in database
    params =
      %{
        user_name: user
      }
      |> SchemaValidator.validate_string([:user_name])

    case params do
      {:error, _} = error ->
        error

      _params ->
        User.insert(params)
        |> case do
          {:ok, _} ->
            # instantiate user_limiter for user through Registry
            :ok

          {:error, _} = error ->
            error
        end
    end
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user_name, amount, currency) do
    params =
      %{
        user_name: user_name,
        name: currency,
        balance: amount
      }
      |> validate_amount_not_zero()

    # check if we have free space for processing user_name request in user_limiter
    # if not, return {:error, :too_many_requests_to_user}
    # if yes, add one active process in limiter and continue

    case params do
      {:error, _} = error ->
        error

      _params ->
        User.get(user_name)
        |> get_currency_account(currency)
        |> deposit_currency_account(amount, params)
    end

    # add one finished process in limiter
    #  return {:ok, new_balance}
  end

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user_name, amount, currency) do
    params =
      %{
        user_name: user_name,
        name: currency,
        balance: amount
      }
      |> validate_amount_not_zero()
      |> SchemaValidator.validate_number([:balance])
      |> SchemaValidator.validate_string([:user_name, :name])
      |> SchemaValidator.validate_not_negative([:balance])

    # check if we have free space for processing user_name request in user_limiter
    # if not, return {:error, :too_many_requests_to_user}
    # if yes, add one active process in limiter and continue

    case params do
      {:error, _} = error ->
        error

      _params ->
        User.get(user_name)
        |> get_currency_account(currency)
        |> withdraw_currency_account(amount, params)
    end

    # add one finished process in limiter
    #  return {:ok, new_balance}
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user_name, currency) do
    params =
      %{
        user_name: user_name,
        name: currency
      }
      |> SchemaValidator.validate_string([:user_name, :name])

    # check if we have free space for processing user_name request in user_limiter
    # if not, return {:error, :too_many_requests_to_user}
    # if yes, add one active process in limiter and continue

    case params do
      {:error, _} = error ->
        error

      _params ->
        User.get(user_name)
        |> get_currency_account(currency)
        |> get_currency_account_balance(user_name)
    end

    # add one finished process in limiter
    #  return {:ok, balance}
  end

  defp get_currency_account_balance(account, _user_name) do
    case account do
      {:error, _} = error ->
        error

      {:ok, account} ->
        {:ok, round_two(account.balance)}
    end
  end

  defp withdraw_currency_account(account, amount, %{user_name: _user_name} = params) do
    case account do
      {:error, :user_does_not_exist} = error ->
        error

      {:error, :currency_account_not_found} = _error ->
        {:error, :not_enough_money}

      {:ok, %CurrencyAccounts{balance: balance}} when balance >= amount ->
        params = %{
          params
          | balance: balance - amount
        }

        CurrencyAccounts.update(params)
        |> case do
          {:ok, account} ->
            {:ok, round_two(account.balance)}

          {:error, _} = error ->
            error
        end

      {:ok, %CurrencyAccounts{balance: balance}} when balance < amount ->
        {:error, :not_enough_money}
    end
  end

  defp deposit_currency_account(currency_account, amount, %{user_name: _user_name} = params) do
    case currency_account do
      {:error, :user_does_not_exist} = error ->
        error

      {:ok, account} ->
        params = %{
          params
          | balance: account.balance + amount
        }

        CurrencyAccounts.update(params)
        |> case do
          {:ok, account} ->
            {:ok, round_two(account.balance)}

          {:error, _} = error ->
            error
        end

      {:error, _} = _error ->
        CurrencyAccounts.insert(params)
        |> case do
          {:ok, account} ->
            {:ok, user} = User.get(params.user_name)

            currency_accounts =
              if user.currency_accounts == nil,
                do: [account.name],
                else: user.currency_accounts ++ [account.name]

            %{
              user
              | currency_accounts: currency_accounts
            }
            |> User.update()

            {:ok, round_two(account.balance)}

          {:error, _} = error ->
            error
        end
    end
  end

  defp validate_amount_not_zero(%{balance: amount} = params) do
    if amount == 0 do
      {:error, :wrong_arguments}
    else
      params
    end
  end

  defp get_currency_account(user, currency) do
    case user do
      {:error, _} = error ->
        error

      {:ok, user} ->
        if user.currency_accounts do
          Enum.find(user.currency_accounts, &(&1 == currency))
          |> case do
            nil ->
              {:error, :currency_account_not_found}

            account_name ->
              {:ok, account} = CurrencyAccounts.get(account_name, user.user_name)
              {:ok, account}
          end
        else
          {:error, :currency_account_not_found}
        end
    end
  end
end
