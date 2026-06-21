defmodule Gin.Hub.TrackDbTest do
  use ExUnit.Case, async: true

  alias Gin.Hub.TrackDb

  @alfa_trackdb """
  track ALFA
  compositeTrack on
  type bigBed 9 + .
  shortLabel ALFA
  longLabel ALFA: Allele Frequency Aggregator

       track ALFA_GLB
       parent ALFA on
       shortLabel NCBI ALFA: Global
       bigDataUrl https://example.com/ALFA_GLB.bb
       type bigBed 9 + .
       url https://www.ncbi.nlm.nih.gov/snp/$$#frequency_tab

       track ALFA_EUR
       parent ALFA on
       shortLabel NCBI ALFA: European
       bigDataUrl https://example.com/ALFA_EUR.bb
  """

  @blueprint_leaf """
  track bp
  compositeTrack on
  shortLabel Blueprint
  subGroup1 experiment Experiment BS-Seq=BS-Seq DNase=DNase

      track bpDNAMeth001
      bigDataUrl http://example.com/file.bb
      parent bp off
      type bigBed 6 .
      shortLabel C000S5.BS.Hypo
      longLabel C000S5 BS-Seq hyper_methylation monocyte from CNAG
      color 250,108,0
      subGroups experiment=BS-Seq sample_description=monocyte sample_source=venous_blood
      metadata MOLECULE=genomic_DNA BIOMATERIAL_TYPE=Primary_Cell SAMPLE_ID=ERS208312 EXPERIMENT_TYPE=DNA_Methylation EXPERIMENT_ID=ERX204011 DONOR_ID=C000S5 DONOR_AGE=65_-_70 DONOR_SEX=Male DONOR_ETHNICITY=Northern_European CELL_TYPE=CD14-positive_classical_monocyte ALIGNMENT_SOFTWARE=GEM ALIGNMENT_SOFTWARE_VERSION=v3 ANALYSIS_SOFTWARE=BS_CALL ANALYSIS_SOFTWARE_VERSION=v2 EPIRR_ID=IHECRE00000027 SAMPLE_ONTOLOGY_URI=http://purl.obolibrary.org/obo/CL_0002057;http://purl.obolibrary.org/obo/UBERON_0013756
      visibility dense
  """

  describe "parse_and_resolve/1 with ALFA hub" do
    setup do
      leaves = TrackDb.parse_and_resolve(@alfa_trackdb)
      {:ok, leaves: leaves}
    end

    test "only returns leaf tracks (those with bigDataUrl)", %{leaves: leaves} do
      assert length(leaves) == 2
      assert Enum.all?(leaves, &Map.has_key?(&1, "bigDataUrl"))
    end

    test "inherits type from composite parent", %{leaves: leaves} do
      eur = Enum.find(leaves, &(&1["track"] == "ALFA_EUR"))
      assert eur["type"] == "bigBed 9 + ."
    end

    test "leaf fields override parent fields", %{leaves: leaves} do
      glb = Enum.find(leaves, &(&1["track"] == "ALFA_GLB"))
      assert glb["shortLabel"] == "NCBI ALFA: Global"
    end
  end

  describe "parse_and_resolve/1 with Blueprint leaf" do
    setup do
      [leaf] = TrackDb.parse_and_resolve(@blueprint_leaf)
      {:ok, leaf: leaf}
    end

    test "parses metadata into a map", %{leaf: leaf} do
      assert is_map(leaf["metadata"])
      assert leaf["metadata"]["MOLECULE"] == "genomic_DNA"
      assert leaf["metadata"]["EXPERIMENT_TYPE"] == "DNA_Methylation"
      assert leaf["metadata"]["DONOR_SEX"] == "Male"
    end

    test "parses subGroups into a map", %{leaf: leaf} do
      assert is_map(leaf["subGroups"])
      assert leaf["subGroups"]["experiment"] == "BS-Seq"
      assert leaf["subGroups"]["sample_description"] == "monocyte"
    end

    test "inherits shortLabel and other fields from composite", %{leaf: leaf} do
      # Composite has no longLabel but leaf does - leaf value wins
      assert leaf["longLabel"] =~ "BS-Seq"
      # Leaf's own shortLabel overrides composite
      assert leaf["shortLabel"] == "C000S5.BS.Hypo"
    end
  end
end
