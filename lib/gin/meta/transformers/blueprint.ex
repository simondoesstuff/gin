defmodule Gin.Meta.Transformers.Blueprint do
  @moduledoc """
  Extracts biological and provenance metadata from Blueprint/ENCODE-style
  `metadata KEY=VALUE ...` and `subGroups key=value ...` fields.

  Works with any hub that uses these conventions.
  """

  alias Gin.Meta.Vocab

  @metadata_mappings [
    {"BIOMATERIAL_TYPE", :biomaterial_type, &Vocab.BiomaterialType.normalize/1},
    {"MOLECULE", :molecule, &Vocab.Molecule.normalize/1},
    {"EXPERIMENT_TYPE", :experiment_type, &Vocab.ExperimentType.normalize/1},
    {"CELL_TYPE", :cell_type, nil},
    {"DONOR_ID", :donor_id, nil},
    {"DONOR_AGE", :donor_age, nil},
    {"DONOR_SEX", :donor_sex, &Vocab.Sex.normalize/1},
    # SEX is used by some hubs as a synonym for DONOR_SEX
    {"SEX", :donor_sex, &Vocab.Sex.normalize/1},
    {"DONOR_ETHNICITY", :donor_ethnicity, nil},
    {"DONOR_HEALTH_STATUS", :donor_health_status, nil},
    {"DISEASE", :disease, nil},
    # TISSUE_TYPE appears in some Blueprint tracks in metadata instead of subGroups
    {"TISSUE_TYPE", :tissue, nil},
    {"SAMPLE_ID", :sample_id, nil},
    {"EXPERIMENT_ID", :experiment_id, nil},
    {"EPIRR_ID", :epirr_id, nil},
    {"ALIGNMENT_SOFTWARE", :alignment_software, nil},
    {"ALIGNMENT_SOFTWARE_VERSION", :alignment_software_version, nil},
    {"ANALYSIS_SOFTWARE", :analysis_software, nil},
    {"ANALYSIS_SOFTWARE_VERSION", :analysis_software_version, nil}
  ]

  # Candidate subGroup keys for each biological dimension, in priority order
  @cell_type_sg_keys ~w[sample_description cell_type cellType]
  @tissue_sg_keys ~w[sample_source tissue Tissue TISSUE_TYPE]
  @experiment_sg_keys ~w[experiment assay]
  @analysis_group_sg_keys ~w[analysis_group analysisGroup lab]
  @analysis_type_sg_keys ~w[analysis_type analysisType]
  @sample_barcode_sg_keys ~w[sample_barcode sampleBarcode barcode]

  # Recognized subGroups keys that duplicate fields we get from metadata.
  # Always consume them to keep `other` clean, but don't override metadata values.
  @redundant_sg_keys ~w[
    sample_description sample_description_3 sample_description_2
    experiment view
  ]

  def transform(raw) do
    {attrs, consumed} = {%{}, MapSet.new()}
    {attrs, consumed} = from_metadata(attrs, consumed, raw)
    {attrs, consumed} = from_subgroups(attrs, consumed, raw)
    {attrs, consumed}
  end

  # --- metadata field -------------------------------------------------------

  defp from_metadata(attrs, consumed, %{"metadata" => meta}) when is_map(meta) do
    {attrs, consumed} =
      Enum.reduce(@metadata_mappings, {attrs, consumed}, fn {mk, field, norm_fn}, {a, c} ->
        case Map.get(meta, mk) do
          nil ->
            {a, c}

          raw_val ->
            val = apply_norm(raw_val, norm_fn)
            {Map.put(a, field, val), MapSet.put(c, "metadata.#{mk}")}
        end
      end)

    # SAMPLE_ONTOLOGY_URI — semicolon-separated list of URIs
    {attrs, consumed} =
      case Map.get(meta, "SAMPLE_ONTOLOGY_URI") do
        nil ->
          {attrs, consumed}

        raw ->
          uris = raw |> String.split(";") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

          {Map.put(attrs, :sample_ontology_uri, uris),
           MapSet.put(consumed, "metadata.SAMPLE_ONTOLOGY_URI")}
      end

    # DISEASE_ONTOLOGY_URI — also semicolon-separated
    {attrs, consumed} =
      case Map.get(meta, "DISEASE_ONTOLOGY_URI") do
        nil ->
          {attrs, consumed}

        raw ->
          uris = raw |> String.split(";") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

          {Map.put(attrs, :disease_ontology_uri, uris),
           MapSet.put(consumed, "metadata.DISEASE_ONTOLOGY_URI")}
      end

    {attrs, consumed}
  end

  defp from_metadata(attrs, consumed, _raw), do: {attrs, consumed}

  # --- subGroups field -------------------------------------------------------

  defp from_subgroups(attrs, consumed, %{"subGroups" => sg}) when is_map(sg) do
    lifts = [
      {:cell_type, @cell_type_sg_keys, nil},
      {:tissue, @tissue_sg_keys, nil},
      {:analysis_group, @analysis_group_sg_keys, nil},
      {:analysis_type, @analysis_type_sg_keys, nil},
      {:sample_barcode, @sample_barcode_sg_keys, nil},
      {:experiment_type, @experiment_sg_keys, &Vocab.ExperimentType.normalize/1}
    ]

    {attrs, consumed} =
      Enum.reduce(lifts, {attrs, consumed}, fn {field, keys, norm_fn}, {a, c} ->
        # Always consume the matching key even if we don't use its value.
        case find_first(sg, keys) do
          nil ->
            {a, c}

          {sg_key, raw_val} ->
            c = MapSet.put(c, "subGroups.#{sg_key}")

            if Map.has_key?(a, field) do
              {a, c}
            else
              {Map.put(a, field, apply_norm(raw_val, norm_fn)), c}
            end
        end
      end)

    # Consume known redundant subGroups keys that don't map to any named field.
    consumed =
      Enum.reduce(@redundant_sg_keys, consumed, fn k, c ->
        if Map.has_key?(sg, k), do: MapSet.put(c, "subGroups.#{k}"), else: c
      end)

    {attrs, consumed}
  end

  defp from_subgroups(attrs, consumed, _raw), do: {attrs, consumed}

  # --- helpers ---------------------------------------------------------------

  defp find_first(map, keys) do
    Enum.find_value(keys, fn k ->
      case Map.get(map, k) do
        nil -> nil
        v -> {k, v}
      end
    end)
  end

  # If no normalizer, return raw. If normalizer returns {:unknown, _}, also
  # return raw — the caller gets the value and the unknown is visible via audit.
  defp apply_norm(raw, nil), do: raw

  defp apply_norm(raw, norm_fn) do
    case norm_fn.(raw) do
      {:ok, canonical} -> canonical
      {:unknown, _} -> raw
    end
  end
end
