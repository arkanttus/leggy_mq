defmodule Leggy do
  @moduledoc """
  Leggy is a AMQP wrapper with pool of channels.

  ## Configuration
  ```elixir
  defmodule YourApp.RabbitRepo do
    use Leggy, host: localhost, username: "user", password: "secret", pool_size: 4
  end
  ```
  """

  require Logger

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Supervisor
      import Logger

      @leggy_opts opts

      def start_link(_opts \\ nil) do
        Supervisor.start_link(
          __MODULE__,
          @leggy_opts,
          name: __MODULE__
        )
      end

      @impl true
      def init(opts) do
        children = [
          {
            Leggy.Connection,
            [
              name: connection_name(),
              hostname: opts[:hostname],
              username: opts[:username],
              password: opts[:password]
            ]
          },
          {
            Leggy.ChannelPool,
            [
              name: pool_name(),
              size: opts[:pool_size],
              connection_name: connection_name()
            ]
          }
        ]

        Supervisor.init(children, strategy: :rest_for_one)
      end

      @doc """
      Cast and validates the params, and parse to a schema struct
      ```elixir
      iex> map = %{user: "r2d2", ttl: 2, valid?: true, requested_at: ~U[2025-10-1521:19:34Z]}
      iex> {:ok, msg} = YourApp.RabbitRepo.cast(YouApp.Schemas.EmailChangeMessage, map)
         {:ok, %YouApp.Schemas.EmailChangeMessage{user: "r2d2", ttl: 2 ...}}
      ```
      """
      @spec cast(schema :: module(), params :: map()) :: {:ok, struct()} | {:error, map()}
      def cast(schema, params) when is_map(params) and is_atom(schema) do
        if Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 0) do
          Leggy.Schema.cast(schema, params)
        else
          raise ArgumentError, "#{inspect(schema)} is not a Leggy.Schema implementation"
        end
      end

      @doc """
      Creates and binds the exchange and the given queue
      ```elixir
      iex> map = %{user: "r2d2", ttl: 2, valid?: true, requested_at: ~U[2025-10-1521:19:34Z]}
      iex> {:ok, msg} = YourApp.RabbitRepo.cast(YouApp.Schemas.EmailChangeMessage, map)
         {:ok, %YouApp.Schemas.EmailChangeMessage{user: "r2d2", ttl: 2 ...}}
      ```
      """
      @spec prepare(schema :: module()) :: :ok | no_return()
      def prepare(schema) when is_atom(schema) do
        if Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 0) do
          %{exchange_name: exchange, queue_name: queue} = schema.__schema__()

          exchange
          |> do_prepare(queue)
          |> handle_result()
        else
          raise ArgumentError, "#{inspect(schema)} is not a Leggy.Schema implementation"
        end
      end

      @doc """
      Publish a casted message in the given exchange
      ```elixir
      iex> {:ok, msg} = YourApp.RabbitRepo.cast(YouApp.Schemas.EmailChangeMessage, map)
      iex> YourApp.RabbitRepo.publish(msg)
      ```
      """
      @spec publish(message :: struct()) :: :ok | {:error, atom()}
      def publish(%schema{__exchange__: exchange, __queue__: _queue} = msg)
          when is_binary(exchange) do
        if Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 0) do
          msg
          |> JSON.encode!()
          |> do_publish(exchange)
          |> handle_result()
        else
          raise ArgumentError, "#{inspect(msg)} is not a Leggy.Schema implementation"
        end
      end

      def publish(msg),
        do: raise(ArgumentError, "#{inspect(msg)} is not a Leggy.Schema implementation")

      @doc """
      Pools the schema's queue for get new messages
      ```elixir
      iex> YourApp.RabbitRepo.get(YouApp.Schemas.EmailChangeMessage)
      {:ok, %YouApp.Schemas.EmailChangeMessage{...}}
      ```
      """
      @spec get(schema :: module()) :: {:ok, struct()} | {:error, map()}
      def get(schema) when is_atom(schema) do
        if Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 0) do
          %{queue_name: queue} = schema.__schema__()

          queue
          |> consume_queue()
          |> case do
            {:ok, :empty} ->
              :empty

            {:ok, {payload, deliv_tag}} ->
              payload
              |> JSON.decode!()
              |> Leggy.Schema.normalize_keys(schema)
              |> cast_or_nack(schema, deliv_tag)
          end
        else
          raise ArgumentError, "#{inspect(schema)} is not a Leggy.Schema implementation"
        end
      end

      defp cast_or_nack(params, schema, delivery_tag) do
        case cast(schema, params) do
          {:ok, _msg} = result ->
            result

          {:error, _reason} = error ->
            Logger.error("Failed to cast received message. Sending nack")
            nack(delivery_tag)
            error
        end
      end

      # Internals

      defp do_prepare(exchange_name, queue_name) do
        Leggy.ChannelPool.run(pool_name(), fn channel ->
          AMQP.Exchange.declare(channel, exchange_name)
          AMQP.Queue.declare(channel, queue_name)
          AMQP.Queue.bind(channel, queue_name, exchange_name)
        end)
      end

      defp do_publish(payload, exchange) do
        Leggy.ChannelPool.run(pool_name(), fn channel ->
          AMQP.Basic.publish(channel, exchange, "", payload)
        end)
      end

      defp consume_queue(queue) do
        Leggy.ChannelPool.run(pool_name(), fn channel ->
          case AMQP.Basic.get(channel, queue) do
            {:ok, payload, %{delivery_tag: delivery_tag}} ->
              {payload, delivery_tag}

            {:empty, _meta} ->
              :empty
          end
        end)
      end

      defp nack(delivery_tag) do
        Leggy.ChannelPool.run(pool_name(), fn channel ->
          AMQP.Basic.nack(channel, delivery_tag)
        end)
      end

      defp connection_name do
        Module.concat(__MODULE__, Connection)
      end

      defp pool_name do
        Module.concat(__MODULE__, ChannelPool)
      end

      defp handle_result({:ok, :ok}), do: :ok
      defp handle_result(result), do: result
    end
  end
end
