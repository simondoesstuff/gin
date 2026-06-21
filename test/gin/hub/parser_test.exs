defmodule Gin.Hub.ParserTest do
  use ExUnit.Case, async: true

  alias Gin.Hub.Parser

  @hub_txt """
  hub ALFA
  shortLabel ALFA Hub
  longLabel NCBI's Allele Frequency Aggregator
  genomesFile genomes.txt
  email snp-admin@ncbi.nlm.nih.gov
  """

  @genomes_txt """
  genome hg19
  trackDb hg19/trackDb.txt

  genome hg38
  trackDb hg38/trackDb.txt
  """

  @trackdb_with_composite """
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

       track ALFA_EUR
       parent ALFA on
       shortLabel NCBI ALFA: European
       bigDataUrl https://example.com/ALFA_EUR.bb
       type bigBed 9 + .
  """

  @trackdb_with_continuation """
  track ATAC
  compositeTrack on
  subGroup1 view Views \\
    A_CPM=ATAC-seq_CPM \\
    B_OCR=Open_chromatin_regions
  shortLabel ATAC-seq

  track leaf1
  parent ATAC
  bigDataUrl https://example.com/leaf1.bb
  """

  test "parse_stanzas parses hub.txt fields" do
    [stanza] = Parser.parse_stanzas(@hub_txt)
    assert stanza["hub"] == "ALFA"
    assert stanza["shortLabel"] == "ALFA Hub"
    assert stanza["genomesFile"] == "genomes.txt"
  end

  test "parse_stanzas splits genomes.txt into two stanzas" do
    stanzas = Parser.parse_stanzas(@genomes_txt)
    assert length(stanzas) == 2
    [hg19, hg38] = stanzas
    assert hg19["genome"] == "hg19"
    assert hg19["trackDb"] == "hg19/trackDb.txt"
    assert hg38["genome"] == "hg38"
  end

  test "parse_track_db splits on track lines including indented ones" do
    stanzas = Parser.parse_track_db(@trackdb_with_composite)
    names = Enum.map(stanzas, & &1["track"])
    assert "ALFA" in names
    assert "ALFA_GLB" in names
    assert "ALFA_EUR" in names
  end

  test "parse_track_db handles backslash continuations" do
    stanzas = Parser.parse_track_db(@trackdb_with_continuation)
    atac = Enum.find(stanzas, &(&1["track"] == "ATAC"))
    assert atac != nil
    # The subGroup1 value should be joined into one string
    assert String.contains?(atac["subGroup1"], "A_CPM=ATAC-seq_CPM")
    assert String.contains?(atac["subGroup1"], "B_OCR=Open_chromatin_regions")
  end

  test "parse_stanzas ignores comment lines" do
    text = """
    # this is a comment
    hub test
    shortLabel Test Hub
    # another comment
    genomesFile genomes.txt
    """

    [stanza] = Parser.parse_stanzas(text)
    assert stanza["hub"] == "test"
    assert stanza["shortLabel"] == "Test Hub"
    refute Map.has_key?(stanza, "#")
  end
end
