defmodule Gin.Meta.Transformers.Blueprint do
  @moduledoc """
  Extracts biological and provenance metadata from Blueprint/ENCODE-style
  `metadata KEY=VALUE ...` and `subGroups key=value ...` fields.

  Works with any hub that uses these conventions.
  """

  alias Gin.Meta.Vocab

  # Uppercase keys follow Blueprint/IHEC convention; lowercase variants handle
  # ENCODE and other hubs that use lowercase metadata keys.
  @metadata_mappings [
    {"BIOMATERIAL_TYPE", :biomaterial_type, &Vocab.BiomaterialType.normalize/1},
    {"MOLECULE", :molecule, &Vocab.Molecule.normalize/1},
    {"EXPERIMENT_TYPE", :experiment_type, &Vocab.ExperimentType.normalize/1},
    {"CELL_TYPE", :cell_type, nil},
    {"DONOR_ID", :donor_id, nil},
    {"DONOR_AGE", :donor_age, nil},
    {"age", :donor_age, nil},
    {"DONOR_SEX", :donor_sex, &Vocab.Sex.normalize/1},
    {"SEX", :donor_sex, &Vocab.Sex.normalize/1},
    {"sex", :donor_sex, &Vocab.Sex.normalize/1},
    {"DONOR_ETHNICITY", :donor_ethnicity, nil},
    {"DONOR_HEALTH_STATUS", :donor_health_status, nil},
    {"DISEASE", :disease, nil},
    {"TISSUE_TYPE", :tissue, nil},
    {"SAMPLE_ID", :sample_id, nil},
    {"EXPERIMENT_ID", :experiment_id, nil},
    {"accession", :accession, nil},
    {"EPIRR_ID", :epirr_id, nil},
    {"ALIGNMENT_SOFTWARE", :alignment_software, nil},
    {"ALIGNMENT_SOFTWARE_VERSION", :alignment_software_version, nil},
    {"ANALYSIS_SOFTWARE", :analysis_software, nil},
    {"ANALYSIS_SOFTWARE_VERSION", :analysis_software_version, nil},
    {"description", :description, nil},

    # Lowercase variants — used by CEMT/IHEC and some other hubs
    {"biomaterial_type", :biomaterial_type, &Vocab.BiomaterialType.normalize/1},
    {"molecule", :molecule, &Vocab.Molecule.normalize/1},
    {"experiment_type", :experiment_type, &Vocab.ExperimentType.normalize/1},
    {"cell_type", :cell_type, nil},
    {"tissue_type", :tissue, nil},
    {"sample_id", :sample_id, nil},
    {"donor_id", :donor_id, nil},
    {"donor_age", :donor_age, nil},
    {"donor_sex", :donor_sex, &Vocab.Sex.normalize/1},
    {"donor_ethnicity", :donor_ethnicity, nil},
    {"donor_health_status", :donor_health_status, nil},
    {"disease", :disease, nil},
    {"epirr_id", :epirr_id, nil},

    # CEMT/IHEC fields — consumed to keep `other` clean, not assembled into GinMeta
    {"reference_registry_id", :epirr_id, nil},
    {"biomaterial_provider", :biomaterial_provider, nil},
    {"donor_age_unit", :donor_age_unit, nil},
    {"donor_life_stage", :donor_life_stage, nil},
    {"tissue_depot", :tissue_depot, nil},
    {"collection_method", :collection_method, nil},
    {"markers", :markers, nil},
    {"passage_if_expanded", :passage_if_expanded, nil},
    {"passage", :passage, nil},
    {"line", :cell_line, nil},
    {"batch", :batch, nil},
    {"differentiation_method", :differentiation_method, nil},
    {"differentiation_stage", :differentiation_stage, nil},
    {"lineage", :lineage, nil}
  ]

  # Candidate subGroup keys for each biological dimension, in priority order
  @cell_type_sg_keys ~w[sample_description cell_type cellType biosample]
  @tissue_sg_keys ~w[sample_source tissue Tissue TISSUE_TYPE]
  @experiment_sg_keys ~w[experiment assay]
  @analysis_group_sg_keys ~w[analysis_group analysisGroup lab]
  @analysis_type_sg_keys ~w[analysis_type analysisType]
  @sample_barcode_sg_keys ~w[sample_barcode sampleBarcode barcode]
  @target_sg_keys ~w[target]

  # Recognized subGroups keys that duplicate fields we get from metadata.
  # Always consume them to keep `other` clean, but don't override metadata values.
  @redundant_sg_keys ~w[
    sample_description sample_description_3 sample_description_2
    experiment data_type
    Comparison NeuN Smooth
    sample_id source track_type
  ]

  # MethBase view codes — all are WGBS-derived bisulfite tracks
  @view_experiment_types %{
    "v1hmr" => "DNA_Methylation",
    "v2amr" => "DNA_Methylation",
    "v3pmd" => "DNA_Methylation",
    "v4sym" => "DNA_Methylation",
    "v5coverage" => "DNA_Methylation"
  }

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
            # Don't overwrite a field already set by a higher-priority mapping
            if Map.has_key?(a, field) do
              {a, MapSet.put(c, "metadata.#{mk}")}
            else
              val = apply_norm(raw_val, norm_fn)
              {Map.put(a, field, val), MapSet.put(c, "metadata.#{mk}")}
            end
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

    # Lowercase URI variants (CEMT/IHEC style)
    {attrs, consumed} =
      case Map.get(meta, "sample_ontology_uri") do
        nil ->
          {attrs, consumed}

        raw ->
          uris = raw |> String.split(";") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
          a = if Map.has_key?(attrs, :sample_ontology_uri), do: attrs, else: Map.put(attrs, :sample_ontology_uri, uris)
          {a, MapSet.put(consumed, "metadata.sample_ontology_uri")}
      end

    {attrs, consumed} =
      case Map.get(meta, "disease_ontology_uri") do
        nil ->
          {attrs, consumed}

        raw ->
          uris = raw |> String.split(";") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
          a = if Map.has_key?(attrs, :disease_ontology_uri), do: attrs, else: Map.put(attrs, :disease_ontology_uri, uris)
          {a, MapSet.put(consumed, "metadata.disease_ontology_uri")}
      end

    {attrs, consumed}
  end

  defp from_metadata(attrs, consumed, _raw), do: {attrs, consumed}

  # --- subGroups field -------------------------------------------------------

  defp from_subgroups(attrs, consumed, %{"subGroups" => sg}) when is_map(sg) do
    lifts = [
      {:cell_type, @cell_type_sg_keys, nil},
      {:tissue, @tissue_sg_keys, &Vocab.Tissue.normalize/1},
      {:analysis_group, @analysis_group_sg_keys, nil},
      {:analysis_type, @analysis_type_sg_keys, nil},
      {:sample_barcode, @sample_barcode_sg_keys, nil},
      {:experiment_type, @experiment_sg_keys, &lift_experiment_type/1},
      # view is a last-resort source for experiment type (e.g. MethBase v1hmr–v5coverage)
      {:experiment_type, ~w[view], &lift_view_experiment_type/1},
      {:experiment_target, @target_sg_keys, nil}
    ]

    {attrs, consumed} =
      Enum.reduce(lifts, {attrs, consumed}, fn {field, keys, norm_fn}, {a, c} ->
        case find_first(sg, keys) do
          nil ->
            {a, c}

          {sg_key, raw_val} ->
            c = MapSet.put(c, "subGroups.#{sg_key}")

            if Map.has_key?(a, field) do
              {a, c}
            else
              case apply_norm(raw_val, norm_fn) do
                nil -> {a, c}
                val -> {Map.put(a, field, val), c}
              end
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

  # Experiment type normalizer:
  #   1. Opaque numeric sample code (Roadmap/MethBase index) → :skip so view fallback can fire
  #   2. Direct vocab match → canonical
  #   3. ENCODE structured format (e.g. "TF_ChIP_seq_CTCF") → canonical
  defp lift_experiment_type(raw) do
    cond do
      sample_code?(raw) -> :skip
      true ->
        case Vocab.ExperimentType.normalize(raw) do
          {:ok, _} = ok -> ok
          {:unknown, _} -> try_structured(raw)
        end
    end
  end

  defp lift_view_experiment_type(raw) do
    case Map.get(@view_experiment_types, raw) do
      nil -> {:unknown, raw}
      canonical -> {:ok, canonical}
    end
  end

  defp sample_code?(val), do: String.match?(val, ~r/^\d+$/)

  defp try_structured(raw) do
    case Vocab.ExperimentType.parse_structured(raw) do
      {:ok, canonical, _target} -> {:ok, canonical}
      :error -> {:unknown, raw}
    end
  end

  # Normalise a raw value via norm_fn.
  # Returns nil when norm_fn signals :skip — caller should not store the field.
  # Strips surrounding double-quotes emitted by some hubs (e.g. MethBase).
  defp apply_norm(raw, nil), do: strip_quotes(raw)

  defp apply_norm(raw, norm_fn) do
    case norm_fn.(strip_quotes(raw)) do
      {:ok, canonical} -> canonical
      {:unknown, _} -> strip_quotes(raw)
      :skip -> nil
    end
  end

  defp strip_quotes(val) do
    val
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
  end
end
