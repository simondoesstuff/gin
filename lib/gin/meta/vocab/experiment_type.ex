defmodule Gin.Meta.Vocab.ExperimentType do
  @moduledoc """
  Controlled vocabulary for assay / experiment types.

  Canonical forms follow the most common ENCODE/Blueprint conventions.
  Histone modification marks use their standard names (e.g. "H3K4me3").
  Sequencing assay names use the form most common in published hub metadata.

  `parse_structured/1` handles ENCODE-style compound names like
  "TF_ChIP_seq_CTCF" or "Histone_ChIP_seq_H3K4me3", returning
  `{:ok, canonical_type, target_or_nil}`.
  """

  use Gin.Meta.Vocab,
    entries: [
      # Chromatin accessibility
      {"ATAC-seq", ~w[atac atac_seq ATAC Chromatin_Accessibility chromatin_accessibility]},
      {"DNase-seq", ~w[dnase dnase_seq DNase DNase-I]},

      # Methylation
      {"DNA_Methylation",
       ~w[BS-Seq bs_seq bisulfite bisulfite_seq WGBS wgbs RRBS rrbs reduced_representation_bisulfite_seq]},

      # Replication timing
      {"Repli-seq", ~w[repli_seq replication_timing]},

      # Histone ChIP-seq marks
      {"H2A.Z", ~w[H2AZ h2az h2a.z H2AFZ h2afz]},
      {"H2A.Zac", ~w[H2AZac h2a.zac]},
      {"H3K4me1", ~w[h3k4me1]},
      {"H3K4me2", ~w[h3k4me2]},
      {"H3K4me3", ~w[h3k4me3]},
      {"H3K4ac", ~w[h3k4ac]},
      {"H3K9ac", ~w[h3k9ac]},
      {"H3K9/14ac", ~w[h3k9_14ac h3k9/14ac H3K9_14ac]},
      {"H3K9me1", ~w[h3k9me1]},
      {"H3K9me2", ~w[h3k9me2]},
      {"H3K9me3", ~w[h3k9me3]},
      {"H3K14ac", ~w[h3k14ac]},
      {"H3K18ac", ~w[h3k18ac]},
      {"H3K23ac", ~w[h3k23ac]},
      {"H3K23me2", ~w[h3k23me2]},
      {"H3K27ac", ~w[h3k27ac]},
      {"H3K27me3", ~w[h3k27me3]},
      {"H3K36me3", ~w[h3k36me3]},
      {"H3K56ac", ~w[h3k56ac]},
      {"H3K79me1", ~w[h3k79me1]},
      {"H3K79me2", ~w[h3k79me2]},
      {"H3F3A", ~w[h3f3a]},
      {"H4K5ac", ~w[h4k5ac]},
      {"H4K8ac", ~w[h4k8ac]},
      {"H4K12ac", ~w[h4k12ac]},
      {"H4K20me1", ~w[h4k20me1]},
      {"H4K91ac", ~w[h4k91ac]},
      {"H2BK5ac", ~w[h2bk5ac]},
      {"H2BK12ac", ~w[h2bk12ac]},
      {"H2BK15ac", ~w[h2bk15ac]},
      {"H2BK20ac", ~w[h2bk20ac]},
      {"H2BK120ac", ~w[h2bk120ac]},
      {"H2AK5ac", ~w[h2ak5ac]},
      {"H2AK9ac", ~w[h2ak9ac]},

      # RNA-seq
      {"mRNA-Seq", ~w[mrna-seq mrna_seq mRNA-seq mRNA mrna PolyA_RNA polya-rnaseq]},
      {"total-RNA-Seq", ~w[total-rna-seq total_rna_seq totalrnaseq total-rnaseq]},
      {"flRNA-seq", ~w[flrna-seq flrna_seq full_length_rna_seq]},
      {"smRNA-seq", ~w[smrna-seq smrna smRNA mirna-seq mirnaseq smallRNA]},
      {"microRNA-seq", ~w[mirna mirna_seq microrna-seq microrna_seq]},
      {"CAGE", ~w[cage]},
      {"RAMPAGE", ~w[rampage]},

      # Protein-RNA interaction
      {"eCLIP", ~w[eclip]},
      {"Control_eCLIP", ~w[control_eclip]},

      # Whole-genome sequencing
      {"WGS", ~w[wgs whole_genome_sequencing]},

      # ChIP-seq generic
      {"ChIP-seq", ~w[chipseq chip_seq chip]},
      {"Input", ~w[input input_control ctrl control]}
    ]

  # Assay token sequences to recognise in compound names, longest first to
  # avoid ChIP matching before ChIP_seq.
  @structured_patterns [
    # Multi-token patterns first (longer match wins)
    {~w[ChIP seq], "ChIP-seq"},
    {~w[DNase seq], "DNase-seq"},
    {~w[ATAC seq], "ATAC-seq"},
    {~w[Repli seq], "Repli-seq"},
    {~w[RNA seq], "mRNA-Seq"},
    {~w[microRNA seq], "microRNA-seq"},
    # Control must precede eCLIP so "Control_eCLIP" matches as a unit
    {~w[Control eCLIP], "Control_eCLIP"},
    # Single-token assay names — target (if any) is everything after
    {~w[eCLIP], "eCLIP"},
    {~w[RAMPAGE], "RAMPAGE"},
    {~w[CAGE], "CAGE"},
    {~w[WGBS], "DNA_Methylation"},
    {~w[RRBS], "DNA_Methylation"}
  ]

  @doc """
  Try to parse an ENCODE-style compound experiment name.

  Returns `{:ok, canonical_type, target_or_nil}` when a known assay token
  sequence is detected, or `:error` if the value does not match any pattern.

  Examples:
      "TF_ChIP_seq_CTCF"         → {:ok, "ChIP-seq", "CTCF"}
      "Histone_ChIP_seq_H3K4me3" → {:ok, "ChIP-seq", "H3K4me3"}
      "DNase_seq_"               → {:ok, "DNase-seq", nil}
      "WGBS_"                    → {:ok, "DNA_Methylation", nil}
  """
  def parse_structured(raw) do
    parts =
      raw
      |> String.split("_")
      |> Enum.reject(&(&1 == ""))

    Enum.find_value(@structured_patterns, :error, fn {tokens, canonical} ->
      case find_token_sequence(parts, tokens) do
        nil -> false
        last_idx -> {:ok, canonical, extract_target(parts, last_idx)}
      end
    end)
  end

  # Returns the index of the last matched token if all tokens appear in order,
  # nil otherwise.
  defp find_token_sequence(parts, tokens) do
    Enum.reduce_while(tokens, {0, -1}, fn token, {search_from, _last_idx} ->
      downcased = String.downcase(token)

      case Enum.find_index(Enum.drop(parts, search_from), &(String.downcase(&1) == downcased)) do
        nil -> {:halt, nil}
        rel_idx -> {:cont, {search_from + rel_idx + 1, search_from + rel_idx}}
      end
    end)
    |> case do
      nil -> nil
      {_, last_idx} -> last_idx
    end
  end

  # Everything after the last matched token index is the target.
  defp extract_target(parts, last_idx) do
    case Enum.drop(parts, last_idx + 1) do
      [] -> nil
      rest -> Enum.join(rest, "_")
    end
  end
end
