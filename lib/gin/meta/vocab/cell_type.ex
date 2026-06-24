defmodule Gin.Meta.Vocab.CellType do
  @moduledoc """
  Controlled vocabulary for cell / sample types.

  Combines two sources:
    - `priv/vocab/cell_type.eterm` — manually curated entries (take priority).
      Covers things CL doesn't: ENCODE cell lines (K562, GM12878), Roadmap
      sample IDs (HUES64), and preferred canonical names.
    - `priv/ontology/cl.obo` — Cell Ontology terms with all synonyms. Slug
      matching connects Blueprint's underscore-separated CL names (e.g.
      "myeloid_cell") to the CL canonical ("myeloid cell") automatically.

  Run `mix gin.audit` to surface unknown values and iterate the vocabulary.
  """

  use Gin.Meta.Vocab,
    eterm: "vocab/cell_type.eterm",
    obo: "ontology/cl.obo"
end
