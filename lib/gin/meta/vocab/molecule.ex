defmodule Gin.Meta.Vocab.Molecule do
  use Gin.Meta.Vocab,
    entries: [
      {"genomic_DNA", ~w[genomic-dna dna gDNA]},
      {"polyA_RNA", ~w[polya_rna polya-rna mRNA polyA]},
      {"total_RNA", ~w[total-rna total_rna RNA]}
    ]
end
