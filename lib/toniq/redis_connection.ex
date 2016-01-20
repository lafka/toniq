defmodule Toniq.RedisConnection do
  use GenServer

  def worker(with_pid) do
    case Application.get_env :toniq, :redis_provider do
      nil ->
        with_pid.(Process.whereis(:toniq_redis))

      {m, f, a} ->
        apply m, f, a ++ [with_pid]
    end
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    redis_url
    |> Exredis.start_using_connection_string
    |> register_redis

    Process.flag(:trap_exit, false)

    {:ok, state}
  end

  defp register_redis({:connection_error, error}) do
    raise """
    \n
    ----------------------------------------------------

    Could not connect to redis.

    The error was: "#{inspect(error)}"

    Some things you could check:

    * Is the redis server running?

    * Is the current redis_url (#{redis_url}) correct?

    ----------------------------------------------------

    """
  end

  defp register_redis(pid) do
    pid
    |> Process.register(:toniq_redis)
  end

  defp redis_url, do: Application.get_env(:toniq, :redis_url)
end
