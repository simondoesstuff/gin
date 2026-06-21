defmodule Gin.Meta.Transformers.Display do
  @doc """
  Consumes known UCSC browser-specific keys that have no biological meaning,
  keeping them out of `other`.
  """

  # Known browser-only keys we consume to avoid `other` noise
  @browser_keys ~w[
    color visibility itemRgb mouseOverField html url urlLabel
    filter.score filterByRange.score filterLimits.score filterValues.name
    dimensions filterComposite sortOrder priority
    parent superTrack compositeTrack view
    subGroup1 subGroup2 subGroup3 subGroup4
    subGroup5 subGroup6 subGroup7 subGroup8
    pennantIcon dragAndDrop
    autoScale maxHeightPixels windowingFunction
    yLineMark yLineOnOff smoothingWindow alwaysZero
    graphTypeDefault gridDefault negateValues
  ]

  def transform(raw) do
    consumed =
      Enum.reduce(@browser_keys, MapSet.new(), fn k, c ->
        if Map.has_key?(raw, k), do: MapSet.put(c, k), else: c
      end)

    {%{}, consumed}
  end
end
