defmodule ExBanking do
  use Application
  alias ExBanking.{UserProcessors}

  @moduledoc """
  Documentation for `ExBanking`.
  """

  def start(_type, _args) do
    ExBanking.Entry.start_link([])
  end

  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) do
    UserProcessors.create_user(user)
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency) do
    task = Task.async(fn -> UserProcessors.deposit(user, amount, currency) end)
    Task.await(task, 6000)
  end

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency) do
    task = Task.async(fn -> UserProcessors.withdraw(user, amount, currency) end)
    Task.await(task, 6000)
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) do
    task = Task.async(fn -> UserProcessors.get_balance(user, currency) end)
    Task.await(task, 6000)
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency) do
    task = Task.async(fn -> UserProcessors.send(from_user, to_user, amount, currency) end)
    Task.await(task, 6000)
  end
end
