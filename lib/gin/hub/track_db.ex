defmodule Gin.Hub.TrackDb do
  alias Gin.Hub.Parser

  # Track types that represent 1D genomic intervals. bigWig (signal/coverage),
  # bigInteract (2D arcs), hic, bam/cram, and unknown types are excluded.
  @interval_types ~w[
    bigBed bed
    bigNarrowPeak narrowPeak
    bigBroadPeak broadPeak
    bigGenePred genePred
    bigPsl psl
    bigBarChart
    vcfTabix
  ]

  @doc """
  Parse trackDb text and return a list of resolved leaf track maps.

  Leaf tracks (those with `bigDataUrl`) have parent field values merged in,
  with the child's own fields taking precedence. Nested fields (`metadata`,
  `subGroups`) are parsed from KEY=VALUE inline strings into maps.
  Only tracks with a 1D interval type are returned.
  """
  def parse_and_resolve(text) do
    raw = Parser.parse_track_db(text)

    by_name = Map.new(raw, fn s -> {Map.get(s, "track", ""), s} end)

    raw
    |> Enum.filter(&Map.has_key?(&1, "bigDataUrl"))
    |> Enum.map(fn leaf ->
      leaf
      |> resolve_inheritance(by_name, _visited = MapSet.new())
      |> normalize_fields()
    end)
    |> Enum.filter(&interval_type?/1)
  end

  defp interval_type?(track) do
    case Map.get(track, "type") do
      nil -> false
      type_str -> (type_str |> String.split() |> List.first("")) in @interval_types
    end
  end

  defp resolve_inheritance(track, by_name, visited) do
    name = Map.get(track, "track", "")

    if MapSet.member?(visited, name) do
      track
    else
      visited = MapSet.put(visited, name)

      case Map.get(track, "parent") do
        nil ->
          track

        parent_ref ->
          parent_name = parent_ref |> String.split() |> List.first()

          case Map.get(by_name, parent_name) do
            nil ->
              track

            parent ->
              resolved = resolve_inheritance(parent, by_name, visited)
              Map.merge(resolved, track)
          end
      end
    end
  end

  defp normalize_fields(track) do
    track
    |> parse_inline_kv("metadata")
    |> parse_inline_kv("subGroups")
  end

  defp parse_inline_kv(%{} = track, key) do
    case Map.get(track, key) do
      nil -> track
      val when is_binary(val) -> Map.put(track, key, parse_kv_string(val))
      _ -> track
    end
  end

  defp parse_kv_string(raw) do
    raw
    |> String.split(~r/\s+/)
    |> Enum.reduce(%{}, fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [k, v] when k != "" -> Map.put(acc, k, v)
        _ -> acc
      end
    end)
  end
end
