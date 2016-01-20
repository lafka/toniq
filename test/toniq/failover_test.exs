# Ensure we can failover jobs from one VM to another when it exits or crashes
defmodule Toniq.FailoverTest do
  use ExUnit.Case

  alias Toniq.RedisConnection

  setup do
    RedisConnection.worker fn(pid) -> Exredis.query(pid, ["FLUSHDB"]) end
    :ok
  end

  defmodule FakeWorker do
    use Toniq.Worker

    def perform do
      send :failover_test, :inherited_job_was_run
    end
  end

  # This test is simplified so we don't need to run multiple erlang vms (it's tricky and
  # leads to unreliable tests). Instead of multiple VMs we simply persist a job as-if
  # there was another VM (different key names in redis) and then stop the keepalive for
  # that fake VM and ensure the job is taken over by the test VM.
  test "orphaned jobs are taken over and run" do
    Process.register self, :failover_test

    current_vm = Toniq.Keepalive.identifier
    other_vm = start_keepalive(:other_vm)

    # Add job to other_vm and check that it only exists there
    add_job(other_vm)
    assert Enum.count(Toniq.JobPersistence.jobs(current_vm)) == 0
    assert Enum.count(Toniq.JobPersistence.jobs(other_vm)) == 1

    # Stop keepalive for other_vm and sure the job is picked up and run.
    # We assume it's run in current_vm here since there is no easy way to check.
    stop_keepalive(:other_vm)
    timeout = 500 # ms
    assert_receive :inherited_job_was_run, timeout
  end

  defp add_job(identifier) do
    Toniq.JobPersistence.store_job(FakeWorker, [], identifier)
  end

  defp start_keepalive(name) do
    {:ok, _pid} = Toniq.Keepalive.start_link(name)
    Toniq.Keepalive.identifier(name)
  end

  defp stop_keepalive(name) do
    name
    |> Process.whereis
    |> unlink_process
    |> Process.exit(:kill)
  end

  defp unlink_process(pid) do
    true = Process.unlink(pid)
    pid
  end
end
