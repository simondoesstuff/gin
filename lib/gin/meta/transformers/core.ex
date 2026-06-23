defmodule Gin.Meta.Transformers.Core do
  @doc """
  Extracts identity fields present on every leaf track.
  Returns `{attrs_map, consumed_flat_keys}`.
  """
  def transform(raw) do
    take_many(raw, %{}, MapSet.new(), [
      {"track", :name},
      {"shortLabel", :short_label},
      {"longLabel", :long_label},
      {"description", :description},
      {"_assembly", :assembly},
      {"bigDataUrl", :big_data_url}
    ])
    |> take_track_type(raw)
  end

  defp take_many(raw, attrs, consumed, mappings) do
    Enum.reduce(mappings, {attrs, consumed}, fn {key, field}, {a, c} ->
      case Map.get(raw, key) do
        nil -> {a, c}
        val -> {Map.put(a, field, val), MapSet.put(c, key)}
      end
    end)
  end

  defp take_track_type({attrs, consumed}, raw) do
    case Map.get(raw, "type") do
      nil ->
        {attrs, consumed}

      val ->
        track_type = val |> String.split() |> List.first()
        {Map.put(attrs, :track_type, track_type), MapSet.put(consumed, "type")}
    end
  end
end
