defmodule Exredis.TakeoverTest do
  use ExUnit.Case

  alias Toniq.RedisConnection

  setup do
    RedisConnection.worker fn(pid) -> Exredis.query(pid, ["FLUSHDB"]) end

    # Disable import to isolate takeover in this test
    Application.put_env(:toniq, :disable_import, true)
    on_exit fn ->
      Application.put_env(:toniq, :disable_import, false)
    end

    :ok
  end

  test "takes over orphaned jobs" do
    current_vm = Toniq.Keepalive.identifier
    other_vm = start_keepalive(:other_vm)

    # Jobs are not taken over while :other_vm is still reporting in
    add_incoming_job(other_vm)
    add_failed_job(other_vm)
    add_job(other_vm)
    :timer.sleep 150
    assert Enum.count(jobs(other_vm)) == 1
    assert Enum.count(failed_jobs(other_vm)) == 1
    assert Enum.count(incoming_jobs(other_vm)) == 1

    assert Enum.count(jobs(current_vm)) == 0
    assert Enum.count(failed_jobs(current_vm)) == 0
    assert Enum.count(incoming_jobs(current_vm)) == 0

    # When :other_vm is stopped, :current_vm moves the jobs to the incoming jobs list
    assert registered?(other_vm)
    stop_keepalive(:other_vm)
    :timer.sleep 200
    assert Enum.count(jobs(other_vm)) == 0
    assert Enum.count(failed_jobs(other_vm)) == 0
    assert Enum.count(incoming_jobs(other_vm)) == 0

    assert Enum.count(jobs(current_vm)) == 0
    assert Enum.count(failed_jobs(current_vm)) == 1
    assert Enum.count(incoming_jobs(current_vm)) == 2

    # check that :other_vm has been deregistered
    refute registered?(other_vm)
  end

  defp start_keepalive(vm_id) do
    {:ok, _pid} = Toniq.Keepalive.start_link(keepalive_name(vm_id))

    vm_id
    |> keepalive_name
    |> Toniq.Keepalive.identifier
  end

  defp add_incoming_job(identifier) do
    Toniq.JobPersistence.store_incoming_job(FakeWorker, [], identifier)
  end

  defp add_job(identifier) do
    Toniq.JobPersistence.store_job(FakeWorker, [], identifier)
  end

  defp add_failed_job(identifier) do
    job = add_job(identifier)
    Toniq.JobPersistence.mark_as_failed(job, "error", identifier)
  end

  defp jobs(identifier) do
    identifier |> Toniq.JobPersistence.jobs
  end

  defp failed_jobs(identifier) do
    identifier |> Toniq.JobPersistence.failed_jobs
  end

  defp incoming_jobs(identifier) do
    identifier |> Toniq.JobPersistence.incoming_jobs
  end

  defp stop_keepalive(vm_id) do
    vm_id
    |> keepalive_name
    |> Process.whereis
    |> unlink_process
    |> Process.exit(:kill)
  end

  defp registered?(identifier) do
    Toniq.KeepalivePersistence.registered_vms
    |> Enum.member? identifier
  end

  defp unlink_process(pid) do
    true = Process.unlink(pid)
    pid
  end

  defp keepalive_name(vm_id) do
    String.to_atom("#{vm_id}:keepalive")
  end
end
