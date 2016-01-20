defmodule Exredis.KeepaliveTest do
  use ExUnit.Case

  alias Toniq.RedisConnection

  setup do
    RedisConnection.worker fn(pid) -> Exredis.query(pid, ["FLUSHDB"]) end
    :ok
  end

  test "periodically updates its keepalive entry in Redis" do
    {:ok, pid} = Toniq.Keepalive.start_link(:test_keepalive)
    :timer.sleep 1 # wait for init to complete

    identifier = Toniq.Keepalive.identifier(:test_keepalive)

    assert hd(registered_vms) == identifier
    assert alive?(identifier)

    # The alive_vms key gets updated periodically
    last_update_time = alive_vm_last_updated_at(identifier)
    :timer.sleep 100
    assert alive_vm_last_updated_at(identifier) > last_update_time

    # Alive vm keys are expired after a timeout
    Process.unlink(pid)
    Process.exit(pid, :kill)

    :timer.sleep 50
    assert alive?(identifier)
    :timer.sleep 50
    refute alive?(identifier)
  end

  defp registered_vms do
    Toniq.KeepalivePersistence.registered_vms
  end

  defp alive_vm_last_updated_at(identifier) do
    identifier
    |> alive_vm_debug_info
    |> :erlang.binary_to_term
    |> Map.get(:last_updated_at)
  end

  defp alive?(identifier) do
    alive_vm_debug_info(identifier) != :undefined
  end

  defp alive_vm_debug_info(identifier) do
    Toniq.KeepalivePersistence.alive_vm_debug_info(identifier)
  end
end
