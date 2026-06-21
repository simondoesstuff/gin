# Gin: Genomic In

Simon Walker

June 17th, 2026

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gin, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gin>.

## Guide

⏺ The quickest way is iex -S mix, then call the pipeline directly:

### Start the REPL

```ex
iex -S mix
```

### Fetch a hub and inspect a track

```ex
alias Gin.Hub.Client
alias Gin.Meta.Transformer

{:ok, tracks} = Client.fetch_all_tracks("http://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub/hub.txt")
```

### Look at one raw track (before transformation)

```ex
tracks |> List.first() |> IO.inspect(pretty: true)
```

### Transform it

```ex
meta = tracks |> List.first() |> Transformer.transform()
IO.inspect(meta, pretty: true)
```

### Check what's left in other across all tracks

```ex
tracks
|> Enum.map(&Transformer.transform/1)
|> Enum.flat_map(fn m -> Map.keys(m.other) end)
|> Enum.frequencies()
|> Enum.sort_by(fn {_, v} -> -v end)
```

For the ALFA hub (simpler, faster):

```ex
{:ok, tracks} = Client.fetch_all_tracks("https://ftp.ncbi.nlm.nih.gov/snp/population_frequency/TrackHub/latest/hub.txt")
```

And the automated tests:

```
mix test # all 44 tests
mix test test/gin/meta/ # just meta/transformer/vocab tests
mix test --trace # verbose, shows each test name
```

The test suite covers the transformer and parser in isolation with inline fixture data, so it runs instantly without any network calls.
