defmodule Leggy.Schema do
  @moduledoc """
  Defines a Leggy schema, responsible to maps external data into Elixir structs

  ## Use example
  ```elixir
  defmodule YouApp.Schemas.EmailChangeMessage do
    use Leggy.Schema
    schema "exchange_name", "queue_name" do
      field :user, :string
      field :ttl, :integer
      field :valid?, :boolean
      field :requested_at, :datetime
    end
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      import Leggy.Schema
      Module.register_attribute(__MODULE__, :fields, accumulate: true)

      @before_compile Leggy.Schema

      def cast(params) when is_map(params) do
        Leggy.Schema.cast(__MODULE__, params)
      end
    end
  end

  defmacro schema(exchange_name, queue_name, do: block) do
    quote do
      @exchange_name unquote(exchange_name)
      @queue_name unquote(queue_name)

      unquote(block)
    end
  end

  defmacro field(name, type) do
    allowed_types = [:string, :integer, :boolean, :datetime]

    unless type in allowed_types do
      raise ArgumentError,
            "invalid field type #{inspect(type)}. Allowed types: #{inspect(allowed_types)}"
    end

    quote do
      @fields {unquote(name), unquote(type)}
    end
  end

  defmacro __before_compile__(env) do
    fields =
      env.module
      |> Module.get_attribute(:fields)
      |> Enum.reverse()

    fields_keys = Enum.map(fields, fn {name, _} -> name end)

    quote do
      @derive {JSON.Encoder, only: unquote(fields_keys)}
      defstruct [
        :__exchange__,
        :__queue__,
        unquote_splicing(fields_keys)
      ]

      def __schema__ do
        %{
          exchange_name: @exchange_name,
          queue_name: @queue_name,
          fields: unquote(fields)
        }
      end
    end
  end

  def cast(schema_module, params) when is_map(params) do
    %{fields: fields, exchange_name: exchange, queue_name: queue} = schema_module.__schema__()

    {data, errors} =
      Enum.reduce(fields, {%{}, %{}}, fn {field, type}, {acc, errs} ->
        case Map.fetch(params, field) do
          {:ok, value} ->
            case cast_value(type, value) do
              {:ok, casted} ->
                {Map.put(acc, field, casted), errs}

              {:error, reason} ->
                {acc, Map.put(errs, field, reason)}
            end

          :error ->
            {acc, Map.put(errs, field, :required)}
        end
      end)

    if map_size(errors) == 0 do
      data_with_metadata =
        Map.merge(data, %{__exchange__: exchange, __queue__: queue})

      {:ok, struct(schema_module, data_with_metadata)}
    else
      {:error, errors}
    end
  end

  def normalize_keys(map, schema_module) do
    %{fields: fields} = schema_module.__schema__()

    Enum.reduce(fields, %{}, fn {field, _type}, acc ->
      key = Atom.to_string(field)

      case Map.fetch(map, key) do
        {:ok, value} ->
          Map.put(acc, field, value)

        :error ->
          acc
      end
    end)
  end

  defp cast_value(:string, value) when is_binary(value),
    do: {:ok, value}

  defp cast_value(:integer, value) when is_integer(value),
    do: {:ok, value}

  defp cast_value(:boolean, value) when is_boolean(value),
    do: {:ok, value}

  defp cast_value(:datetime, value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, :invalid_datetime}
    end
  end

  defp cast_value(:datetime, value) do
    if match?(%DateTime{}, value) do
      {:ok, value}
    else
      {:error, {:invalid_type, :datetime}}
    end
  end

  defp cast_value(type, _value),
    do: {:error, {:invalid_type, type}}
end
