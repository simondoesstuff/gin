defmodule Gin.Ontology.Obo do
  @moduledoc """
  Minimal OBO 1.2 term parser.

  Extracts `{name, [synonyms]}` pairs from `[Term]` stanzas, filtered to
  terms whose `id:` matches a given prefix (default `"CL:"`). Obsolete
  terms are skipped. All synonym scopes (EXACT, RELATED, NARROW, BROAD)
  are included as aliases.
  """

  @doc """
  Parse an OBO file at `path` and return `{name, [synonyms]}` pairs.

  Only terms whose id starts with `id_prefix` are returned.
  """
  def parse_terms(path, id_prefix \\ "CL:") do
    path
    |> File.read!()
    |> split_stanzas()
    |> Enum.filter(&term_stanza?(&1, id_prefix))
    |> Enum.reject(&obsolete?/1)
    |> Enum.flat_map(&extract_term/1)
  end

  # Split file into stanzas (blank-line delimited).
  defp split_stanzas(content) do
    content
    |> String.split("\n\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp term_stanza?(stanza, prefix) do
    String.starts_with?(stanza, "[Term]") and
      String.contains?(stanza, "\nid: #{prefix}")
  end

  defp obsolete?(stanza), do: String.contains?(stanza, "\nis_obsolete: true")

  defp extract_term(stanza) do
    lines = String.split(stanza, "\n")

    name =
      Enum.find_value(lines, fn line ->
        case line do
          "name: " <> rest -> String.trim(rest)
          _ -> nil
        end
      end)

    # Only EXACT and NARROW synonyms are used as aliases.
    # RELATED and BROAD scopes are too loose and cause false cross-species matches
    # (e.g. "macrophage" RELATED to the insect haemocyte "plasmatocyte").
    synonyms =
      lines
      |> Enum.flat_map(fn line ->
        case Regex.run(~r/^synonym: "(.+)" (?:EXACT|NARROW) \[/, line) do
          [_, s] -> [s]
          _ -> []
        end
      end)
      |> Enum.uniq()

    if name, do: [{name, synonyms}], else: []
  end
end
