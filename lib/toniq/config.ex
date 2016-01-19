# There is no default config system in Elixir yet, but this workaround seems to work.
defmodule Toniq.Config do
  def init do
    # keepalive_interval: The time between each time the vm reports in as being alive.
    # keepalive_expiration: The time until other vms can take over jobs from a stopped vm.
    # takeover_interval: The time between checking for orphaned jobs originally belonging to other vms to move to incoming_jobs.
    # job_import_interval: The time between checking for incoming_jobs to enqueue and run.
    # redis_key_prefix: The prefix that will be added to all redis keys used by toniq. You will want to customize this if you have multiple applications using the same redis server. Keep in mind though that redis servers consume very little memory, and running one per application guarantees there is no coupling between the apps.
    default :toniq,
      redis_key_prefix:     Application.get_env(:toniq, :redis_key_prefix,     :toniq),
      redis_url:            Application.get_env(:toniq, :redis_url,            "redis://localhost:6379/0"),
      keepalive_interval:   Application.get_env(:toniq, :keepalive_interval,   4000), # ms
      keepalive_expiration: Application.get_env(:toniq, :keepalive_expiration, 10000), # ms
      takeover_interval:    Application.get_env(:toniq, :takeover_interval,    2000), # ms
      job_import_interval:  Application.get_env(:toniq, :job_import_interval,  2000), # ms
      retry_strategy:       Application.get_env(:toniq, :retry_strategy,       Toniq.RetryWithIncreasingDelayStrategy)
  end

  defp default(scope, options) do
    options |> Enum.each fn ({key, value}) ->
      :ok == Application.put_env(scope, key, value)
    end
  end
end
