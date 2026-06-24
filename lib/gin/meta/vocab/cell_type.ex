defmodule Gin.Meta.Vocab.CellType do
  @moduledoc """
  Controlled vocabulary for cell / sample types.

  Canonical names are the most common published forms. Slug matching covers
  separator and case variants automatically. Explicit alias lists handle
  abbreviations and codes that slug matching cannot bridge.

  Populated from `priv/vocab/cell_type.eterm`. Run `mix gin.audit` to
  surface unknown values and iterate the vocabulary.
  """

  use Gin.Meta.Vocab, eterm: "vocab/cell_type.eterm"
end
