defmodule Helpers.SchemaValidator do
  def validate_string(params, validation_fields) do
    params
    |> case do
      {:error, _} = error ->
        error

      params ->
        validation_fields
        |> Enum.map(fn key ->
          case is_binary(Map.get(params, key)) do
            true -> {key, Map.get(params, key)}
            _ -> {:error, :wrong_arguments}
          end
        end)
        |> Enum.filter(fn
          {:error, _} -> true
          _ -> false
        end)
        |> case do
          [] -> params
          _ -> {:error, :wrong_arguments}
        end
    end
  end

  def validate_number(params, validation_fields) do
    params
    |> case do
      {:error, _} = error ->
        error

      params ->
        validation_fields
        |> Enum.map(fn key ->
          case is_number(Map.get(params, key)) do
            true -> {key, Map.get(params, key)}
            _ -> {:error, :wrong_arguments}
          end
        end)
        |> Enum.filter(fn
          {:error, _} -> true
          _ -> false
        end)
        |> case do
          [] -> params
          _ -> {:error, :wrong_arguments}
        end
    end
  end

  def validate_not_negative(params, validation_fields) do
    params
    |> case do
      {:error, _} = error ->
        error

      params ->
        validation_fields
        |> Enum.map(fn key ->
          case Map.get(params, key) >= 0 do
            true -> {key, Map.get(params, key)}
            _ -> {:error, :wrong_arguments}
          end
        end)
        |> Enum.filter(fn
          {:error, _} -> true
          _ -> false
        end)
        |> case do
          [] -> params
          _ -> {:error, :wrong_arguments}
        end
    end
  end

  def validate_required(params, required_fields) do
    params
    |> case do
      {:error, _} = error ->
        error

      params ->
        required_fields
        |> Enum.map(fn key ->
          if Map.has_key?(params, key) do
            {:ok, key}
          else
            {:error, "#{key} is required"}
          end
        end)
        |> Enum.filter(fn
          {:error, _} -> true
          _ -> false
        end)
        |> case do
          [] ->
            params

          errors ->
            errors_cat = errors |> Enum.map(fn {_, error} -> error end) |> Enum.join(", ")
            {:error, errors_cat}
        end
    end
  end

  def validate_not_nil(params, required_fields) do
    params
    |> case do
      {:error, _} = error ->
        error

      params ->
        required_fields
        |> Enum.map(fn key ->
          if !is_nil(Map.get(params, key)) do
            {:ok, key}
          else
            {:error, :wrong_arguments}
          end
        end)
        |> Enum.filter(fn
          {:error, _} -> true
          _ -> false
        end)
        |> case do
          [] ->
            {:ok, params}

          _ ->
            {:error, :wrong_arguments}
        end
    end
  end
end
