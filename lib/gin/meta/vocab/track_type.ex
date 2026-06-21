defmodule Gin.Meta.Vocab.TrackType do
  @moduledoc "UCSC binary track file formats."

  use Gin.Meta.Vocab,
    entries: [
      {"bigBed", ~w[bigbed bb]},
      {"bigWig", ~w[bigwig bw wig]},
      {"bigGenePred", ~w[bigenepred]},
      {"bigNarrowPeak", ~w[bignarrowpeak narrowpeak]},
      {"bigBroadPeak", ~w[bigbroadpeak broadpeak]},
      {"bigInteract", ~w[biginteract interact]},
      {"bigMaf", ~w[bigmaf maf]},
      {"bigPsl", ~w[bigpsl psl]},
      {"bigChain", ~w[bigchain chain]},
      {"vcfTabix", ~w[vcftabix vcf]},
      {"bam", ~w[BAM]}
    ]
end
