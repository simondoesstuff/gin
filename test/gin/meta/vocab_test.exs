defmodule Gin.Meta.VocabTest do
  use ExUnit.Case, async: true

  alias Gin.Meta.Vocab.{BiomaterialType, ExperimentType, Molecule, Sex, TrackType}

  describe "Molecule" do
    test "normalizes canonical form" do
      assert {:ok, "genomic_DNA"} = Molecule.normalize("genomic_DNA")
    end

    test "case-insensitive match" do
      assert {:ok, "genomic_DNA"} = Molecule.normalize("GENOMIC_DNA")
    end

    test "alias mapping" do
      assert {:ok, "polyA_RNA"} = Molecule.normalize("mRNA")
      assert {:ok, "total_RNA"} = Molecule.normalize("RNA")
    end

    test "unknown returns raw" do
      assert {:unknown, "protein"} = Molecule.normalize("protein")
    end

    test "known?/1" do
      assert Molecule.known?("genomic_DNA")
      refute Molecule.known?("protein")
    end
  end

  describe "BiomaterialType" do
    test "normalizes all four types" do
      assert {:ok, "Primary_Cell"} = BiomaterialType.normalize("Primary_Cell")
      assert {:ok, "Primary_Cell"} = BiomaterialType.normalize("primary_cell")
      assert {:ok, "Cell_Line"} = BiomaterialType.normalize("cell_line")
      assert {:ok, "Primary_Tissue"} = BiomaterialType.normalize("Primary_Tissue")
      assert {:ok, "Primary_Cell_Culture"} = BiomaterialType.normalize("Primary_Cell_Culture")
    end

    test "unknown" do
      assert {:unknown, "organoid"} = BiomaterialType.normalize("organoid")
    end
  end

  describe "Sex" do
    test "normalizes values" do
      assert {:ok, "Female"} = Sex.normalize("Female")
      assert {:ok, "Female"} = Sex.normalize("female")
      assert {:ok, "Female"} = Sex.normalize("F")
      assert {:ok, "Male"} = Sex.normalize("M")
      assert {:ok, "Unknown"} = Sex.normalize("NA")
    end

    test "unknown" do
      assert {:unknown, "intersex"} = Sex.normalize("intersex")
    end
  end

  describe "ExperimentType" do
    test "histone marks normalize correctly" do
      assert {:ok, "H3K4me3"} = ExperimentType.normalize("H3K4me3")
      assert {:ok, "H3K4me3"} = ExperimentType.normalize("h3k4me3")
      assert {:ok, "H3K27ac"} = ExperimentType.normalize("H3K27ac")
    end

    test "RNA-seq case variants both normalize" do
      assert {:ok, "mRNA-Seq"} = ExperimentType.normalize("mRNA-Seq")
      assert {:ok, "mRNA-Seq"} = ExperimentType.normalize("mRNA-seq")
    end

    test "methylation aliases" do
      assert {:ok, "DNA_Methylation"} = ExperimentType.normalize("BS-Seq")
      assert {:ok, "DNA_Methylation"} = ExperimentType.normalize("WGBS")
    end

    test "ATAC aliases" do
      assert {:ok, "ATAC-seq"} = ExperimentType.normalize("Chromatin_Accessibility")
      assert {:ok, "ATAC-seq"} = ExperimentType.normalize("ATAC")
    end

    test "unknown histone mark" do
      assert {:unknown, "H3K4me4"} = ExperimentType.normalize("H3K4me4")
    end
  end

  describe "TrackType" do
    test "bigBed and bigWig" do
      assert {:ok, "bigBed"} = TrackType.normalize("bigBed")
      assert {:ok, "bigBed"} = TrackType.normalize("bigbed")
      assert {:ok, "bigWig"} = TrackType.normalize("bigwig")
      assert {:ok, "bigWig"} = TrackType.normalize("bw")
    end

    test "unknown format" do
      assert {:unknown, "coolFile"} = TrackType.normalize("coolFile")
    end
  end
end
