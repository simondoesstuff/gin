defmodule Gin.Meta.Vocab.Tissue do
  @moduledoc """
  Controlled vocabulary for tissue / anatomical source.

  Canonical names follow Blueprint/IHEC conventions where applicable. Slug
  matching covers separator and case variants. Explicit aliases bridge
  anatomical abbreviation codes (BrainEpigenome), Roadmap uppercase anatomy
  codes, and ENCODE RNA dash-separated paths.

  Populated from `priv/vocab/tissue.eterm`. Run `mix gin.audit` to surface
  unknown values and iterate the vocabulary.
  """

  use Gin.Meta.Vocab, eterm: "vocab/tissue.eterm"
end
