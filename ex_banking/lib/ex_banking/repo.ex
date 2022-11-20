defmodule ExBanking.Repo do
  use GenServer

  def start_link(opts) do
    server = Keyword.fetch(opts, :name)
    GenServer.start_link(__MODULE__, server, opts)
  end

  # client side
  @doc """
  pid: can be pid or server name
  key: search key
  Returns {:ok, value} or {:error, reason}
  """
  def get(pid, key) do
    case :ets.lookup(pid, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :key_not_found}
    end
  end

  @doc """
  pid: can be pid or server name
  key: key
  opts: value to be inserted as map
  Returns {:error, reason} if key is already there or {:ok, value} if inserted
  """
  def insert(pid, key, opts \\ %{}) do
    case :ets.lookup(pid, key) do
      [] ->
        :ets.insert(pid, {key, opts})
        value = :ets.lookup(pid, key) |> List.first() |> elem(1)

        {:ok, value}

      [{^key, _value}] ->
        {:error, :key_already_exists}
    end
  end

  @doc """
  pid: can be pid or server name
  key: key
  opts: value to be inserted as map
  Returns {:ok, value} if key is already there or {:error, reason}
  """
  def update(pid, key, opts) do
    case :ets.lookup(pid, key) do
      [{^key, _value}] ->
        :ets.insert(pid, {key, opts})
        value = :ets.lookup(pid, key) |> List.first() |> elem(1)

        {:ok, value}

      [] ->
        {:error, :key_not_found}
    end
  end

  @doc """
  pid: can be pid or server name
  key: key
  Returns {:error, reason} if key is not found or {:ok, value} if deleted
  """
  def delete(pid, key) do
    case :ets.lookup(pid, key) do
      [{^key, _value}] -> {:ok, :ets.delete(pid, key)}
      [] -> {:error, :key_not_found}
    end
  end

  # server side

  def init({:ok, table}) do
    table = :ets.new(table, [:named_table, :public, read_concurrency: true])
    {:ok, table}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
