defmodule Leggy.Connection do
  @moduledoc """
  Genserver responsible for create a connection with RabbitMQ broker
  """

  use GenServer
  require Logger

  ## Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def get_connection(name) do
    GenServer.call(name, :get_conn)
  end

  ## GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      opts: opts,
      conn: nil
    }

    {:ok, connect(state)}
  end

  @impl true
  def handle_call(:get_conn, _from, %{conn: conn} = state) when not is_nil(conn) do
    {:reply, conn, state}
  end

  def handle_call(:get_conn, _from, state) do
    state = connect(state)
    {:reply, state.conn, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    Logger.warning("RabbitMQ connection lost, reconnecting...")
    {:noreply, connect(%{state | conn: nil})}
  end

  @impl true
  def handle_info(:retry, state) do
    {:noreply, connect(state)}
  end

  ## Internal

  defp connect(%{opts: opts} = state) do
    conn_opts = [host: opts[:hostname], username: opts[:username], password: opts[:password]]

    case AMQP.Connection.open(conn_opts) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        %{state | conn: conn}

      {:error, reason} ->
        Logger.error("Error by connect to RabbitMQ: #{inspect(reason)}")
        Process.send_after(self(), :retry, 5_000)
        state
    end
  end
end
