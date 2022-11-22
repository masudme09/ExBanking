defmodule ExBanking.Entry do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(_) do
    children = [
      {Registry, keys: :unique, name: ExBanking.Registry},
      {DynamicSupervisor, name: ExBanking.UserLimiterSupervisor, strategy: :one_for_one},
      %{id: :users_repo, start: {ExBanking.Repo, :start_link, [[name: :users]]}},
      %{
        id: :user_currency_accounts_repo,
        start: {ExBanking.Repo, :start_link, [[name: :currency_accounts]]}
      }
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
