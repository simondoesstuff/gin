defmodule Gin.Meta.TransformerTest do
  use ExUnit.Case, async: true

  alias Gin.Meta.Transformer
  alias Gin.Meta.GinMeta
  alias Gin.Meta.GinMeta.{Donor, Experiment, Provenance, Sample}

  @blueprint_track %{
    "track" => "bpDNAMeth001",
    "_assembly" => "hg38",
    "bigDataUrl" => "http://example.com/file.bb",
    "type" => "bigBed 6 .",
    "shortLabel" => "C000S5.BS.Hypo",
    "longLabel" => "C000S5 BS-Seq hyper_methylation monocyte from CNAG",
    "color" => "250,108,0",
    "visibility" => "dense",
    "parent" => "bp off",
    "dragAndDrop" => "subTracks",
    "subGroups" => %{
      "experiment" => "BS-Seq",
      "sample_description" => "monocyte",
      "sample_source" => "venous_blood",
      "sample_barcode" => "C000S5",
      "analysis_group" => "CNAG",
      "analysis_type" => "hyper_methylation",
      "view" => "region"
    },
    "metadata" => %{
      "MOLECULE" => "genomic_DNA",
      "BIOMATERIAL_TYPE" => "Primary_Cell",
      "SAMPLE_ID" => "ERS208312",
      "EXPERIMENT_TYPE" => "DNA_Methylation",
      "EXPERIMENT_ID" => "ERX204011",
      "DONOR_ID" => "C000S5",
      "DONOR_AGE" => "65_-_70",
      "DONOR_SEX" => "Male",
      "DONOR_ETHNICITY" => "Northern_European",
      "DONOR_HEALTH_STATUS" => "Healthy",
      "CELL_TYPE" => "CD14-positive_classical_monocyte",
      "ALIGNMENT_SOFTWARE" => "GEM",
      "ALIGNMENT_SOFTWARE_VERSION" => "v3",
      "ANALYSIS_SOFTWARE" => "BS_CALL",
      "ANALYSIS_SOFTWARE_VERSION" => "v2",
      "EPIRR_ID" => "IHECRE00000027",
      "SAMPLE_ONTOLOGY_URI" =>
        "http://purl.obolibrary.org/obo/CL_0002057;http://purl.obolibrary.org/obo/UBERON_0013756",
      "DISEASE" => "Acute_Myeloid_Leukemia",
      "DISEASE_ONTOLOGY_URI" =>
        "http://ncimeta.nci.nih.gov/ncimbrowser/ConceptReport.jsp?dictionary=NCI%20MetaThesaurus&code=C0023467",
      "NOVEL_FIELD" => "some_value_we_dont_recognize"
    }
  }

  @alfa_track %{
    "track" => "ALFA_GLB",
    "_assembly" => "hg19",
    "bigDataUrl" => "https://example.com/ALFA_GLB.bb",
    "type" => "bigBed 9 + .",
    "shortLabel" => "NCBI ALFA: Global",
    "longLabel" => "ALFA global allele frequencies",
    "parent" => "ALFA on",
    "url" => "https://www.ncbi.nlm.nih.gov/snp/$$",
    "urlLabel" => "NCBI Variation Page"
  }

  describe "transform/1 with Blueprint track" do
    setup do: {:ok, meta: Transformer.transform(@blueprint_track)}

    test "returns a GinMeta struct", %{meta: meta} do
      assert %GinMeta{} = meta
    end

    test "populates core identity fields", %{meta: meta} do
      assert meta.name == "bpDNAMeth001"
      assert meta.assembly == "hg38"
      assert meta.track_type == "bigBed"
      assert meta.big_data_url == "http://example.com/file.bb"
      assert meta.short_label == "C000S5.BS.Hypo"
    end

    test "builds Sample sub-struct", %{meta: meta} do
      assert %Sample{} = meta.sample
      assert meta.sample.id == "ERS208312"
      assert meta.sample.cell_type == "CD14-positive_classical_monocyte"
      assert meta.sample.biomaterial_type == "Primary_Cell"
      assert meta.sample.tissue == "venous_blood"
      assert meta.sample.barcode == "C000S5"
    end

    test "parses ontology URIs into a list on Sample", %{meta: meta} do
      assert is_list(meta.sample.ontology_uri)
      assert length(meta.sample.ontology_uri) == 2
      assert "http://purl.obolibrary.org/obo/CL_0002057" in meta.sample.ontology_uri
    end

    test "builds Donor sub-struct", %{meta: meta} do
      assert %Donor{} = meta.sample.donor
      assert meta.sample.donor.id == "C000S5"
      assert meta.sample.donor.age == "65_-_70"
      assert meta.sample.donor.sex == "Male"
      assert meta.sample.donor.ethnicity == "Northern_European"
      assert meta.sample.donor.health_status == "Healthy"
      assert meta.sample.donor.disease == "Acute_Myeloid_Leukemia"
    end

    test "parses disease ontology URI list on Donor", %{meta: meta} do
      assert is_list(meta.sample.donor.disease_ontology_uri)
      assert length(meta.sample.donor.disease_ontology_uri) == 1
    end

    test "builds Experiment sub-struct", %{meta: meta} do
      assert %Experiment{} = meta.experiment
      assert meta.experiment.id == "ERX204011"
      assert meta.experiment.type == "DNA_Methylation"
      assert meta.experiment.molecule == "genomic_DNA"
      assert meta.experiment.epirr_id == "IHECRE00000027"
    end

    test "builds Provenance sub-struct", %{meta: meta} do
      assert %Provenance{} = meta.provenance
      assert meta.provenance.analysis_group == "CNAG"
      assert meta.provenance.analysis_type == "hyper_methylation"
      assert meta.provenance.alignment_software == "GEM"
      assert meta.provenance.alignment_software_version == "v3"
      assert meta.provenance.analysis_software == "BS_CALL"
      assert meta.provenance.analysis_software_version == "v2"
    end

    test "unknown metadata fields go into other", %{meta: meta} do
      assert meta.other["metadata.NOVEL_FIELD"] == "some_value_we_dont_recognize"
    end

    test "recognized keys do not appear in other", %{meta: meta} do
      refute Map.has_key?(meta.other, "metadata.EXPERIMENT_TYPE")
      refute Map.has_key?(meta.other, "metadata.CELL_TYPE")
      refute Map.has_key?(meta.other, "metadata.DONOR_SEX")
      refute Map.has_key?(meta.other, "parent")
      refute Map.has_key?(meta.other, "dragAndDrop")
    end

    test "other contains only truly unknown keys", %{meta: meta} do
      assert meta.other == %{"metadata.NOVEL_FIELD" => "some_value_we_dont_recognize"}
    end
  end

  describe "transform/1 with minimal ALFA track" do
    setup do: {:ok, meta: Transformer.transform(@alfa_track)}

    test "populates core fields", %{meta: meta} do
      assert meta.name == "ALFA_GLB"
      assert meta.assembly == "hg19"
      assert meta.track_type == "bigBed"
    end

    test "sample, experiment, provenance are nil when absent", %{meta: meta} do
      assert meta.sample == nil
      assert meta.experiment == nil
      assert meta.provenance == nil
    end

    test "browser-only fields are not in other", %{meta: meta} do
      refute Map.has_key?(meta.other, "url")
      refute Map.has_key?(meta.other, "urlLabel")
      refute Map.has_key?(meta.other, "parent")
    end
  end
end
