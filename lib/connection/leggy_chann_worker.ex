defmodule Leggy.ChannelWorker do
  @moduledoc """
  Worker module representing a channel in a pool of channels.
  """

  use GenServer
  require Logger

  ## Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_channel(pid) do
    GenServer.call(pid, :get_channel)
  end

  ## GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      conn: Leggy.Connection.get_connection(opts[:connection_name]),
      channel: nil,
      opts: opts
    }

    {:ok, create_channel(state)}
  end

  @impl true
  def handle_call(:get_channel, _from, %{channel: chann} = state) when not is_nil(chann) do
    {:reply, chann, state}
  end

  @impl true
  def handle_call(:get_channel, _from, state) do
    state = create_channel(state)
    {:reply, state.channel, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    Logger.warning("RabbitMQ channel lost, reconnecting...")
    {:noreply, create_channel(state)}
  end

  @impl true
  def handle_info(:retry, state) do
    {:noreply, create_channel(state)}
  end

  ## Internals

  defp create_channel(%{conn: conn} = state) do
    case AMQP.Channel.open(conn) do
      {:ok, chann} ->
        Process.monitor(chann.pid)
        %{state | channel: chann}

      {:error, reason} ->
        Logger.error("Error to open channel: #{inspect(reason)}")
        Process.send_after(self(), :retry, 5_000)
        state
    end
  end
end
