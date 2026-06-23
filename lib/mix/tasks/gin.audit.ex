defmodule Mix.Tasks.Gin.Audit do
  @moduledoc """
  Fetch one or more track hubs and audit the vocabulary coverage of named
  GinMeta fields.

  Usage:

      mix gin.audit [hub_url ...]

  With no arguments, runs against the default hub set. For each named field
  that has an enumerable value space, prints observed values sorted by
  frequency and flags values not yet in any vocab. Also prints `other` key
  frequencies so you can spot anything the transformer pipeline is missing.

  Example:

      mix gin.audit http://ftp.ebi.ac.uk/.../hub.txt
  """

  use Mix.Task

  alias Gin.Hub.Client
  alias Gin.Meta.Transformer
  alias Gin.Meta.Vocab

  @shortdoc "Audit vocab coverage across one or more track hubs"


  @default_hubs [
    "http://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub/hub.txt"
  ]

  # Fields to audit: {label, path into GinMeta, vocab module or nil}
  # Path uses get_in/2 keys — atoms for structs navigated via Map.get on struct maps.
  @audited_fields [
    {"experiment.type", [:experiment, :type], Vocab.ExperimentType},
    {"experiment.target", [:experiment, :target], nil},
    {"experiment.molecule", [:experiment, :molecule], Vocab.Molecule},
    {"sample.biomaterial_type", [:sample, :biomaterial_type], Vocab.BiomaterialType},
    {"sample.cell_type", [:sample, :cell_type], nil},
    {"sample.tissue", [:sample, :tissue], Vocab.Tissue},
    {"sample.donor.sex", [:sample, :donor, :sex], Vocab.Sex},
    {"sample.donor.ethnicity", [:sample, :donor, :ethnicity], nil},
    {"sample.donor.health_status", [:sample, :donor, :health_status], nil},
    {"sample.donor.disease", [:sample, :donor, :disease], nil},
    {"provenance.analysis_group", [:provenance, :analysis_group], nil},
    {"provenance.analysis_type", [:provenance, :analysis_type], nil},
    {"provenance.alignment_software", [:provenance, :alignment_software], nil},
    {"provenance.analysis_software", [:provenance, :analysis_software], nil}
  ]

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    hubs = if args == [], do: @default_hubs, else: args

    metas =
      Enum.flat_map(hubs, fn url ->
        Mix.shell().info("Fetching #{url} ...")

        case Client.fetch_all_tracks(url) do
          {:ok, tracks} ->
            Mix.shell().info("  #{length(tracks)} leaf tracks")
            Enum.map(tracks, &Transformer.transform/1)

          {:error, reason} ->
            Mix.shell().error("  Failed: #{inspect(reason)}")
            []
        end
      end)

    Mix.shell().info("\n#{length(metas)} total tracks across #{length(hubs)} hub(s)\n")

    Enum.each(@audited_fields, fn {label, path, vocab_mod} ->
      values =
        metas
        |> Enum.map(&get_nested(&1, path))
        |> Enum.reject(&is_nil/1)

      if values == [] do
        Mix.shell().info("=== #{label} — no values observed ===\n")
      else
        freqs = values |> Enum.frequencies() |> Enum.sort_by(fn {_, n} -> -n end)
        present = length(values)
        unique = length(freqs)

        Mix.shell().info("=== #{label} (#{present} values, #{unique} unique) ===")

        Enum.each(freqs, fn {val, count} ->
          tag =
            cond do
              is_nil(vocab_mod) -> ""
              vocab_mod.known?(val) -> ""
              true -> "  [?]"
            end

          Mix.shell().info("  #{String.pad_leading(Integer.to_string(count), 6)}  #{val}#{tag}")
        end)

        Mix.shell().info("")
      end
    end)

    # other key frequencies
    other_freqs =
      metas
      |> Enum.flat_map(fn m -> Map.keys(m.other) end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, n} -> -n end)

    if other_freqs == [] do
      Mix.shell().info("=== other — no unrecognized keys ===")
    else
      Mix.shell().info("=== other (unrecognized keys) ===")

      Enum.each(other_freqs, fn {k, count} ->
        Mix.shell().info("  #{String.pad_leading(Integer.to_string(count), 6)}  #{k}")
      end)
    end
  end

  # Walk a path of atom keys through nested structs (converted to maps via Map.from_struct).
  defp get_nested(struct, [key | rest]) when is_struct(struct) do
    get_nested(Map.from_struct(struct), [key | rest])
  end

  defp get_nested(map, [key | rest]) when is_map(map) do
    case Map.get(map, key) do
      nil -> nil
      val -> get_nested(val, rest)
    end
  end

  defp get_nested(val, []), do: val
  defp get_nested(nil, _), do: nil
end
