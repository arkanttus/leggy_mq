defmodule Leggy.ChannelPool do
  @moduledoc """
  A wrapper for a pool library implementation. In this case, Poolex
  """

  def child_spec(opts) do
    %{
      id: opts[:name],
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts) do
    Poolex.start_link(
      pool_id: opts[:name],
      worker_module: Leggy.ChannelWorker,
      workers_count: opts[:size],
      worker_args: [
        [connection_name: opts[:connection_name]]
      ]
    )
  end

  def run(pool_name, fun) do
    Poolex.run(pool_name, fn worker_pid ->
      channel = Leggy.ChannelWorker.get_channel(worker_pid)
      fun.(channel)
    end)
  end
end
