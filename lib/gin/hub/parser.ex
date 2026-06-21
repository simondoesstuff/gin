defmodule Gin.Hub.Parser do
  @doc """
  Parse a hub config file (hub.txt, genomes.txt) into a list of stanza maps.
  Each stanza is `%{key => value}` with string keys and values.
  """
  def parse_stanzas(text) do
    text
    |> join_continuations()
    |> String.split("\n")
    |> Enum.reject(&comment?/1)
    |> chunk_by_blank_lines()
    |> Enum.map(&lines_to_map/1)
    |> Enum.reject(&Enum.empty?/1)
  end

  @doc """
  Parse a trackDb.txt into raw stanza maps. Uses `track` lines as stanza
  boundaries since some hubs omit blank lines between stanzas.
  """
  def parse_track_db(text) do
    text
    |> join_continuations()
    |> String.split("\n")
    |> Enum.reject(&comment?/1)
    |> chunk_by_track_line()
    |> Enum.map(&lines_to_map/1)
    |> Enum.reject(&Enum.empty?/1)
  end

  defp join_continuations(text) do
    String.replace(text, ~r/\\\n\s*/, " ")
  end

  defp comment?(line) do
    line |> String.trim() |> String.starts_with?("#")
  end

  defp chunk_by_blank_lines(lines) do
    lines
    |> Enum.chunk_by(&(String.trim(&1) == ""))
    |> Enum.reject(fn chunk -> Enum.all?(chunk, &(String.trim(&1) == "")) end)
  end

  defp chunk_by_track_line(lines) do
    {chunks, current} =
      Enum.reduce(lines, {[], []}, fn line, {chunks, current} ->
        trimmed = String.trim(line)

        if String.starts_with?(trimmed, "track ") and current != [] do
          {[Enum.reverse(current) | chunks], [line]}
        else
          {chunks, [line | current]}
        end
      end)

    all = if current != [], do: [Enum.reverse(current) | chunks], else: chunks
    Enum.reverse(all)
  end

  defp lines_to_map(lines) do
    lines
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ~r/\s+/, parts: 2) do
        [key, value] -> Map.put(acc, key, String.trim(value))
        [key] -> Map.put(acc, key, "")
        _ -> acc
      end
    end)
  end
end
