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
    centerLabelsDense darkerLabels height hoverMetadata
    viewLimits viewUi colorByStrand
    configurable
    group noInherit visibilityViewDefaults subTrack
    minGrayLevel useScore maxLimit noScoreFilter
    pValueFilter pValueFilterLimits
    qValueFilter qValueFilterLimits
    signalFilter signalFilterLimits
    filter.nbp filterLimits filterText.name filterLabel.name
    fileSortOrder maxItems psuTrack itrack
    defaultLabelFields labelFields
    barChartColors barChartMetric barChartUnit barChartLabel barChartBars
    table
    dataVersion showSubtrackColorOnUi boxedCfg
    aggregate container
    thickDrawItem exonArrows exonArrowsDense
    searchIndex searchTrix showTopScorers
    scoreFilter sepFields spectrum
    bedNameLabel
    dividers
  ]

  def transform(raw) do
    consumed =
      Enum.reduce(@browser_keys, MapSet.new(), fn k, c ->
        if Map.has_key?(raw, k), do: MapSet.put(c, k), else: c
      end)

    {%{}, consumed}
  end
end
