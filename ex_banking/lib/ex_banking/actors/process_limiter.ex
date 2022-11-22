defmodule ExBanking.ProcessLimiter do
  use GenServer

  def start_link(
        {:via, Registry,
         {ExBanking.Registry, _ = user_name,
          %{
            max_allowed: _max_allowed,
            active_process: _active_process
          } = state}} = _opts
      ) do
    name = {:via, Registry, {ExBanking.Registry, user_name}}

    GenServer.start_link(__MODULE__, state, name: name)
  end

  def init(state) do
    {:ok, state}
  end

  def get_active_process_count(pid) do
    GenServer.call(pid, :get_active_process_count)
  end

  def check_free_space(pid) do
    GenServer.call(pid, :check_free_space)
  end

  def add_active_process(pid) do
    GenServer.call(pid, :add_active_process)
  end

  def add_finished_process(pid) do
    GenServer.call(pid, :add_finished_process)
  end

  # server callbacks

  def handle_call(:get_active_process_count, _from, state) do
    {:reply, state.active_process, state}
  end

  def handle_call(:check_free_space, _from, state) do
    {:reply, state.active_process < state.max_allowed, state}
  end

  def handle_call(:add_active_process, _from, state) do
    %{active_process: active_process, max_allowed: max_allowed} = state

    cond do
      active_process < max_allowed ->
        {:reply, :ok, %{state | active_process: active_process + 1}}

      true ->
        {:reply, :error, state}
    end
  end

  def handle_call(:add_finished_process, _from, state) do
    %{active_process: active_process, max_allowed: _max_allowed} = state

    cond do
      active_process > 0 ->
        {:reply, :ok, %{state | active_process: active_process - 1}}

      true ->
        {:reply, :ok, state}
    end
  end
end
