defmodule ExBanking.NumericOperations do
  def to_float(nil), do: 0.0

  def to_float(str) when is_binary(str) do
    case Float.parse(str) do
      {value, text} ->
        case text do
          "" -> value
          _ -> :error
        end

      :error ->
        :error
    end
  end

  def to_float(float) when is_float(float), do: float
  def to_float(integer) when is_integer(integer), do: integer * 1.0

  def to_integer(nil), do: 0
  def to_integer(str) when is_binary(str), do: String.to_integer(str)
  def to_integer(integer) when is_integer(integer), do: integer
  def to_integer(float) when is_float(float), do: round(float)

  def round_two(float) when is_float(float) do
    Float.round(float, 2)
  end

  def round_two(float) when is_integer(float) do
    to_float(float)
    |> round_two()
  end
end
