defmodule Gin.Meta.Vocab.CellType do
  @moduledoc """
  Controlled vocabulary for cell / sample types.

  Combines four sources (in priority order):
    - `priv/vocab/cell_type_common.eterm` — shared terms for both species.
    - `priv/vocab/cell_type_human.eterm` — human-specific lines and samples.
    - `priv/vocab/cell_type_mouse.eterm` — mouse-specific lines (VISION/PSU).
    - `priv/ontology/cl.obo` — Cell Ontology; fills gaps not covered by eterms.

  `normalize/1` covers all entries (union). `normalize/2` accepts `:human`,
  `:mouse`, or `:any` for assembly-aware lookups. Use
  `Gin.Meta.Vocab.assembly_species/1` to map an assembly string to a species.

  Run `mix gin.audit` to surface unknown values and iterate the vocabulary.
  """

  use Gin.Meta.Vocab,
    eterm: "vocab/cell_type_common.eterm",
    eterm_human: "vocab/cell_type_human.eterm",
    eterm_mouse: "vocab/cell_type_mouse.eterm",
    obo: "ontology/cl.obo"
end
