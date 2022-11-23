defmodule ExBanking.UserProcessors do
  @doc """
  This module is responsible for processing user requests.
  """
  import ExBanking.NumericOperations
  alias Helpers.SchemaValidator
  alias ExBanking.{User, CurrencyAccounts, ProcessLimiter}

  def create_user(user) do
    params =
      %{
        user_name: user
      }
      |> SchemaValidator.validate_string([:user_name])

    User.insert(params)
    |> case do
      {:ok, user} ->
        ExBanking.UserLimiterSupervisor.start_child(user)
        :ok

      {:error, _} = error ->
        error
    end
  end

  def deposit(user_name, amount, currency) do
    params =
      %{
        user_name: user_name,
        name: currency,
        balance: amount
      }
      |> validate_amount_not_zero()

    cond do
      params == {:error, :wrong_arguments} ->
        params

      Registry.lookup(ExBanking.Registry, user_name) == [] ->
        {:error, :user_does_not_exist}

      Registry.lookup(ExBanking.Registry, user_name) ->
        [{pid, _}] = Registry.lookup(ExBanking.Registry, user_name)

        if ProcessLimiter.check_free_space(pid) do
          ProcessLimiter.add_active_process(pid)

          User.get(user_name)
          |> get_currency_account(currency)
          |> deposit_currency_account(amount, params)
          |> tap(fn _ ->
            ProcessLimiter.add_finished_process(pid)
            # naive timer to prevent too many requests to user
            Process.sleep(100)
          end)
        else
          {:error, :too_many_requests_to_user}
        end
    end
  end

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

    cond do
      params == {:error, :wrong_arguments} ->
        params

      Registry.lookup(ExBanking.Registry, user_name) == [] ->
        {:error, :user_does_not_exist}

      Registry.lookup(ExBanking.Registry, user_name) ->
        [{pid, _}] = Registry.lookup(ExBanking.Registry, user_name)

        # naive timer to prevent too many requests to user
        Process.sleep(100)

        if ProcessLimiter.check_free_space(pid) do
          ProcessLimiter.add_active_process(pid)

          User.get(user_name)
          |> get_currency_account(currency)
          |> withdraw_currency_account(amount, params)
          |> tap(fn _ -> ProcessLimiter.add_finished_process(pid) end)
        else
          {:error, :too_many_requests_to_user}
        end
    end
  end

  def get_balance(user_name, currency) do
    params =
      %{
        user_name: user_name,
        name: currency
      }
      |> SchemaValidator.validate_string([:user_name, :name])

    cond do
      params == {:error, :wrong_arguments} ->
        params

      Registry.lookup(ExBanking.Registry, user_name) == [] ->
        {:error, :user_does_not_exist}

      Registry.lookup(ExBanking.Registry, user_name) ->
        [{pid, _}] = Registry.lookup(ExBanking.Registry, user_name)

        # naive timer to prevent too many requests to user
        Process.sleep(100)

        if ProcessLimiter.check_free_space(pid) do
          ProcessLimiter.add_active_process(pid)

          User.get(user_name)
          |> get_currency_account(currency)
          |> get_currency_account_balance(user_name)
          |> tap(fn _ -> ProcessLimiter.add_finished_process(pid) end)
        else
          {:error, :too_many_requests_to_user}
        end
    end
  end

  def send(from_user, to_user, amount, currency) do
    params =
      %{
        from_user: from_user,
        to_user: to_user,
        name: currency,
        balance: amount
      }
      |> validate_amount_not_zero()
      |> SchemaValidator.validate_number([:balance])
      |> SchemaValidator.validate_string([:from_user, :to_user, :name])
      |> SchemaValidator.validate_not_negative([:balance])

    cond do
      params == {:error, :wrong_arguments} ->
        params

      Registry.lookup(ExBanking.Registry, from_user) == [] ->
        {:error, :sender_does_not_exist}

      Registry.lookup(ExBanking.Registry, to_user) == [] ->
        {:error, :receiver_does_not_exist}

      Registry.lookup(ExBanking.Registry, from_user) ->
        [{from_pid, _}] = Registry.lookup(ExBanking.Registry, from_user)
        [{to_pid, _}] = Registry.lookup(ExBanking.Registry, to_user)

        # naive timer to prevent too many requests to user
        Process.sleep(100)

        from_process_status = ProcessLimiter.check_free_space(from_pid)
        to_process_status = ProcessLimiter.check_free_space(to_pid)

        cond do
          from_process_status == false ->
            {:error, :too_many_requests_to_sender}

          to_process_status == false ->
            {:error, :too_many_requests_to_receiver}

          from_process_status && to_process_status ->
            [from_pid, to_pid]
            |> Enum.each(fn pid -> ProcessLimiter.add_active_process(pid) end)

            withdraw_naive(from_user, amount, currency)
            |> case do
              {:ok, from_user_balance} ->
                deposit_naive(to_user, amount, currency)
                |> case do
                  {:ok, to_user_balance} ->
                    {:ok, from_user_balance, to_user_balance}

                  {:error, _} = error ->
                    error
                end

              {:error, _} = error ->
                error
            end
        end
        |> tap(fn _ ->
          [from_pid, to_pid]
          |> Enum.each(fn pid -> ProcessLimiter.add_finished_process(pid) end)
        end)
    end
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

      {:error, _} = error ->
        error
    end
  end

  defp deposit_currency_account(currency_account, amount, %{user_name: _user_name} = params) do
    case currency_account do
      {:error, :user_does_not_exist} = error ->
        error

      {:error, :currency_account_not_found} = _error ->
        CurrencyAccounts.insert(params)
        |> case do
          {:ok, account} ->
            _ = User.associate_currency_account(account.user_name, account)

            {:ok, round_two(account.balance)}

          {:error, _} = error ->
            error
        end

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

      {:error, _} = error ->
        error
    end
  end

  defp validate_amount_not_zero(%{balance: amount} = params) do
    if amount == 0 do
      {:error, :wrong_arguments}
    else
      params
    end
  end

  defp get_currency_account({:error, _} = error, _currency), do: error

  defp get_currency_account({:ok, user}, currency) do
    cond do
      is_nil(user.currency_accounts) ->
        {:error, :currency_account_not_found}

      is_nil(Enum.find(user.currency_accounts, &(&1 == currency))) ->
        {:error, :currency_account_not_found}

      true ->
        CurrencyAccounts.get(currency, user.user_name)
    end
  end

  # wthdraw without process limiter
  defp withdraw_naive(user_name, amount, currency) do
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

    cond do
      params == {:error, :wrong_arguments} ->
        params

      Registry.lookup(ExBanking.Registry, user_name) == [] ->
        {:error, :user_does_not_exist}

      Registry.lookup(ExBanking.Registry, user_name) ->
        User.get(user_name)
        |> get_currency_account(currency)
        |> withdraw_currency_account(amount, params)
    end
  end

  # deposit without process limiter
  defp deposit_naive(user_name, amount, currency) do
    params =
      %{
        user_name: user_name,
        name: currency,
        balance: amount
      }
      |> validate_amount_not_zero()

    cond do
      params == {:error, :wrong_arguments} ->
        params

      Registry.lookup(ExBanking.Registry, user_name) == [] ->
        {:error, :user_does_not_exist}

      Registry.lookup(ExBanking.Registry, user_name) ->
        User.get(user_name)
        |> get_currency_account(currency)
        |> deposit_currency_account(amount, params)
    end
  end
end
