defmodule Gin.Meta.Vocab.ExperimentType do
  @moduledoc """
  Controlled vocabulary for assay / experiment types.

  Canonical forms follow the most common ENCODE/Blueprint conventions.
  Histone modification marks use their standard names (e.g. "H3K4me3").
  Sequencing assay names use the form most common in published hub metadata.
  """

  use Gin.Meta.Vocab,
    entries: [
      # Chromatin accessibility
      {"ATAC-seq", ~w[atac atac_seq ATAC Chromatin_Accessibility chromatin_accessibility]},
      {"DNase-seq", ~w[dnase dnase_seq DNase DNase-I]},

      # Methylation
      {"DNA_Methylation", ~w[BS-Seq bs_seq bisulfite bisulfite_seq WGBS wgbs]},

      # Histone ChIP-seq marks
      {"H2A.Z", ~w[H2AZ h2az h2a.z]},
      {"H2A.Zac", ~w[H2AZac h2a.zac]},
      {"H3K4me1", ~w[h3k4me1]},
      {"H3K4me2", ~w[h3k4me2]},
      {"H3K4me3", ~w[h3k4me3]},
      {"H3K9ac", ~w[h3k9ac]},
      {"H3K9/14ac", ~w[h3k9_14ac h3k9/14ac H3K9_14ac]},
      {"H3K9me1", ~w[h3k9me1]},
      {"H3K9me2", ~w[h3k9me2]},
      {"H3K9me3", ~w[h3k9me3]},
      {"H3K27ac", ~w[h3k27ac]},
      {"H3K27me3", ~w[h3k27me3]},
      {"H3K36me3", ~w[h3k36me3]},
      {"H3K79me2", ~w[h3k79me2]},
      {"H4K20me1", ~w[h4k20me1]},

      # RNA-seq
      {"mRNA-Seq", ~w[mrna-seq mrna_seq mRNA-seq PolyA_RNA polya-rnaseq]},
      {"total-RNA-Seq", ~w[total-rna-seq total_rna_seq totalrnaseq total-rnaseq]},
      {"flRNA-seq", ~w[flrna-seq flrna_seq full_length_rna_seq]},
      {"smRNA-seq", ~w[smrna-seq mirna-seq mirnaseq smallRNA]},

      # ChIP-seq generic
      {"ChIP-seq", ~w[chipseq chip_seq chip]},
      {"Input", ~w[input input_control ctrl control]}
    ]
end
