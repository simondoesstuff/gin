defmodule Gin.Meta.GinMeta do
  @moduledoc """
  Standardized schema for a genomic track's metadata.

  Named fields cover known cross-hub semantics. Fields are grouped into
  nested sub-structs by concern. Anything the transformer pipeline recognizes
  as a known key but does not elevate, plus all unrecognized keys, accumulate
  in `other` using dot-notation (e.g. `"metadata.SOME_FIELD"`,
  `"subGroups.some_key"`).
  """

  alias __MODULE__.{Experiment, Provenance, Sample}

  defstruct [
    # Core track identity
    :name,
    :short_label,
    :long_label,
    :description,
    :assembly,
    :track_type,
    :big_data_url,

    # Nested concern groups
    :sample,
    :experiment,
    :provenance,
    other: %{}
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          short_label: String.t() | nil,
          long_label: String.t() | nil,
          description: String.t() | nil,
          assembly: String.t() | nil,
          track_type: String.t() | nil,
          big_data_url: String.t() | nil,
          sample: Sample.t() | nil,
          experiment: Experiment.t() | nil,
          provenance: Provenance.t() | nil,
          other: %{String.t() => term()}
        }
end

defmodule Gin.Meta.GinMeta.Donor do
  @moduledoc "Human donor / subject from whom the sample was collected."

  defstruct [
    :id,
    :age,
    :sex,
    :ethnicity,
    :health_status,
    :disease,
    :disease_ontology_uri
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          age: String.t() | nil,
          sex: String.t() | nil,
          ethnicity: String.t() | nil,
          health_status: String.t() | nil,
          disease: String.t() | nil,
          disease_ontology_uri: [String.t()] | nil
        }
end

defmodule Gin.Meta.GinMeta.Sample do
  @moduledoc "Biological sample — the material that was sequenced."

  defstruct [
    :id,
    :barcode,
    :cell_type,
    :tissue,
    :biomaterial_type,
    :ontology_uri,
    :donor
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          barcode: String.t() | nil,
          cell_type: String.t() | nil,
          tissue: String.t() | nil,
          biomaterial_type: String.t() | nil,
          ontology_uri: [String.t()] | nil,
          donor: Gin.Meta.GinMeta.Donor.t() | nil
        }
end

defmodule Gin.Meta.GinMeta.Experiment do
  @moduledoc "The biological assay that produced the track."

  defstruct [
    :id,
    :accession,
    :type,
    :sub_type,
    :target,
    :molecule,
    :epirr_id
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          accession: String.t() | nil,
          type: String.t() | nil,
          sub_type: String.t() | nil,
          target: String.t() | nil,
          molecule: String.t() | nil,
          epirr_id: String.t() | nil
        }
end

defmodule Gin.Meta.GinMeta.Provenance do
  @moduledoc "Computational pipeline and analysis provenance."

  defstruct [
    :analysis_group,
    :analysis_type,
    :alignment_software,
    :alignment_software_version,
    :analysis_software,
    :analysis_software_version
  ]

  @type t :: %__MODULE__{
          analysis_group: String.t() | nil,
          analysis_type: String.t() | nil,
          alignment_software: String.t() | nil,
          alignment_software_version: String.t() | nil,
          analysis_software: String.t() | nil,
          analysis_software_version: String.t() | nil
        }
end
