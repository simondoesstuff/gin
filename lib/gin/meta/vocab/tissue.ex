defmodule Gin.Meta.Vocab.Tissue do
  @moduledoc """
  Controlled vocabulary for tissue / anatomical source.

  Blueprint tissue names are used as canonicals where possible. Brain region
  codes from BrainEpigenome (sort-key prefix like "A_BA9") are normalised to
  standard anatomical names. ENCODE RNA hub uses dash-separated anatomical
  paths (e.g. "Brain-Frontal_Lobe-Left") which are collapsed to their
  canonical region.
  """

  use Gin.Meta.Vocab,
    entries: [
      # Blood and haematopoietic compartments
      {"venous_blood", ~w[venous_Blood]},
      {"cord_blood", ~w[cord_Blood]},
      {"capillary_blood", ~w[capillary_Blood]},
      {"bone_marrow", ~w[bone_Marrow]},

      # Lymphoid tissues
      {"tonsil", []},
      {"lymph_node", ~w[lymph_Node]},
      {"thymus", []},
      {"thymus_lymphoid_tissue", ~w[thymus_Lymphoid_Tissue]},

      # Solid organs
      {"liver", []},
      {"thyroid_gland", ~w[thyroid Thyroid]},
      {"colon", ~w[Large_Intestine-Colon large_intestine-colon]},
      {"ascending_colon",
       ~w[Large_Intestine-Colon-Ascending_(Right) large_intestine-colon-ascending_(right)]},
      {"sigmoid_colon",
       ~w[Large_Intestine-Colon-Rectosigmoid large_intestine-colon-rectosigmoid]},

      # Cell lines (Blueprint uses this as a tissue value for in vitro lines)
      {"Cell_Line", ~w[cell_line]},

      # Brain (general)
      {"brain", ~w[Brain]},

      # Brain regions (BrainEpigenome sort-key prefix A–F stripped;
      # ENCODE RNA uses "Brain-<Region>-<Side>" paths)
      {"frontal_cortex",
       ~w[BA9 a_ba9 ba9 Brain-Frontal_Lobe-Right brain-frontal_lobe-right
          Brain-Frontal_Lobe-Left brain-frontal_lobe-left]},
      {"anterior_cingulate_cortex", ~w[BA24 b_ba24 ba24]},
      {"hippocampus", ~w[HC c_hc hc]},
      {"nucleus_accumbens", ~w[NAcc d_nacc nacc]},
      {"temporal_lobe",
       ~w[Brain-Temporal_lobe-Left brain-temporal_lobe-left
          Brain-right_temporal brain-right_temporal]},
      {"occipital_lobe",
       ~w[Brain-Occipetal_Lobe-Right brain-occipetal_lobe-right]}
    ]
end
