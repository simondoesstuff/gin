defmodule Gin.Meta.Vocab.BiomaterialType do
  use Gin.Meta.Vocab,
    entries: [
      {"Primary_Cell", ~w[primary_cell PrimaryCell]},
      {"Primary_Cell_Culture", ~w[primary_cell_culture PrimaryCellCulture]},
      {"Primary_Tissue", ~w[primary_tissue PrimaryTissue]},
      {"Cell_Line", ~w[cell_line cellline CellLine]}
    ]
end
