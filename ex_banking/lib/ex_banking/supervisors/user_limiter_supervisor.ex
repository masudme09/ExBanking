defmodule ExBanking.UserLimiterSupervisor do
  use DynamicSupervisor
  alias ExBanking.ProcessLimiter

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(%ExBanking.User{} = user) do
    user_name = user.user_name
    max_allowed = 10
    active_process = 0

    state = %{
      max_allowed: max_allowed,
      active_process: active_process
    }

    DynamicSupervisor.start_child(
      __MODULE__,
      {ProcessLimiter, {:via, Registry, {ExBanking.Registry, user_name, state}}}
    )
  end
end
