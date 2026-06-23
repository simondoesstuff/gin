defmodule Gin.Meta.Transformer do
  alias Gin.Meta.GinMeta
  alias Gin.Meta.GinMeta.{Donor, Experiment, Provenance, Sample}
  alias Gin.Meta.Transformers.{Blueprint, Core, Display}

  @transformers [&Core.transform/1, &Blueprint.transform/1, &Display.transform/1]

  @doc """
  Run all transformers on a raw resolved track stanza map and return a GinMeta.

  Each transformer returns `{flat_attrs, consumed_flat_keys}`. Flat keys use
  dot-notation for nested sources (e.g. `"metadata.CELL_TYPE"`). Keys not
  consumed by any transformer end up in `GinMeta.other`.
  """
  def transform(raw_track) do
    {flat_attrs, consumed} =
      Enum.reduce(@transformers, {%{}, MapSet.new()}, fn t, {acc, con} ->
        {partial, keys} = t.(raw_track)
        {Map.merge(acc, partial), MapSet.union(con, keys)}
      end)

    other =
      raw_track
      |> flatten_raw()
      |> Enum.reject(fn {k, _} -> MapSet.member?(consumed, k) end)
      |> Map.new()

    assemble(flat_attrs, other)
  end

  # --- assembly ---------------------------------------------------------------

  defp assemble(a, other) do
    donor =
      pick(a, %{
        id: :donor_id,
        age: :donor_age,
        sex: :donor_sex,
        ethnicity: :donor_ethnicity,
        health_status: :donor_health_status,
        disease: :disease,
        disease_ontology_uri: :disease_ontology_uri
      })
      |> nilify(Donor)

    sample =
      pick(a, %{
        id: :sample_id,
        barcode: :sample_barcode,
        cell_type: :cell_type,
        tissue: :tissue,
        biomaterial_type: :biomaterial_type,
        ontology_uri: :sample_ontology_uri
      })
      |> Map.put(:donor, donor)
      |> nilify(Sample)

    experiment =
      pick(a, %{
        id: :experiment_id,
        accession: :accession,
        type: :experiment_type,
        sub_type: :experiment_sub_type,
        target: :experiment_target,
        molecule: :molecule,
        epirr_id: :epirr_id
      })
      |> nilify(Experiment)

    provenance =
      pick(a, %{
        analysis_group: :analysis_group,
        analysis_type: :analysis_type,
        alignment_software: :alignment_software,
        alignment_software_version: :alignment_software_version,
        analysis_software: :analysis_software,
        analysis_software_version: :analysis_software_version
      })
      |> nilify(Provenance)

    %GinMeta{
      name: a[:name],
      short_label: a[:short_label],
      long_label: a[:long_label],
      description: a[:description],
      assembly: a[:assembly],
      track_type: a[:track_type],
      big_data_url: a[:big_data_url],
      sample: sample,
      experiment: experiment,
      provenance: provenance,
      other: other
    }
  end

  # Build a plain map with struct field names from the flat attr map.
  # mapping is %{struct_field => flat_attr_key}
  defp pick(attrs, mapping) do
    Map.new(mapping, fn {struct_key, attr_key} -> {struct_key, attrs[attr_key]} end)
  end

  # If all values are nil, return nil. Otherwise build the struct.
  defp nilify(field_map, mod) do
    if Enum.all?(field_map, fn {_, v} -> is_nil(v) end) do
      nil
    else
      struct(mod, field_map)
    end
  end

  # --- flatten raw -----------------------------------------------------------

  defp flatten_raw(raw) do
    Enum.flat_map(raw, fn
      {k, v} when is_map(v) ->
        Enum.map(v, fn {sk, sv} -> {"#{k}.#{sk}", sv} end)

      {k, v} ->
        [{k, v}]
    end)
  end
end
