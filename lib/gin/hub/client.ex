defmodule Gin.Hub.Client do
  alias Gin.Hub.{Parser, TrackDb}

  @doc "Fetch and parse hub.txt into a field map."
  def fetch_hub(hub_url) do
    with {:ok, text} <- get(hub_url) do
      fields = Parser.parse_stanzas(text) |> List.first(%{})
      {:ok, fields}
    end
  end

  @doc """
  Fetch genomes.txt for a hub and return a list of
  `{assembly, trackdb_url, genome_stanza_map}` tuples.
  """
  def fetch_genomes(hub_url) do
    base = base_url(hub_url)

    with {:ok, hub} <- fetch_hub(hub_url),
         genomes_path = Map.get(hub, "genomesFile", "genomes.txt"),
         genomes_url = "#{base}/#{genomes_path}",
         {:ok, text} <- get(genomes_url) do
      pairs =
        Parser.parse_stanzas(text)
        |> Enum.filter(&Map.has_key?(&1, "genome"))
        |> Enum.map(fn s ->
          assembly = Map.fetch!(s, "genome")
          trackdb_url = "#{base}/#{Map.fetch!(s, "trackDb")}"
          {assembly, trackdb_url, s}
        end)

      {:ok, pairs}
    end
  end

  @doc "Fetch and parse trackDb.txt for one assembly, returning resolved leaf tracks."
  def fetch_tracks(trackdb_url) do
    with {:ok, text} <- get(trackdb_url) do
      {:ok, TrackDb.parse_and_resolve(text)}
    end
  end

  @doc """
  Fetch all leaf tracks across all assemblies in a hub.
  Each track map gets a synthetic `_assembly` key injected.
  """
  def fetch_all_tracks(hub_url) do
    with {:ok, genomes} <- fetch_genomes(hub_url) do
      tracks =
        Enum.flat_map(genomes, fn {assembly, trackdb_url, _} ->
          case fetch_tracks(trackdb_url) do
            {:ok, ts} -> Enum.map(ts, &Map.put(&1, "_assembly", assembly))
            {:error, _} -> []
          end
        end)

      {:ok, tracks}
    end
  end

  defp get(url) do
    uri = URI.parse(url)
    url_charlist = String.to_charlist(url)

    ssl_opts =
      if uri.scheme == "https" do
        [
          ssl: [
            verify: :verify_peer,
            cacerts: :public_key.cacerts_get(),
            server_name_indication: String.to_charlist(uri.host),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ]
          ]
        ]
      else
        []
      end

    case :httpc.request(:get, {url_charlist, []}, ssl_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _, _}} -> {:error, {:http_status, status, url}}
      {:error, reason} -> {:error, {reason, url}}
    end
  end

  defp base_url(hub_url) do
    uri = URI.parse(hub_url)
    %{uri | path: Path.dirname(uri.path)} |> URI.to_string()
  end
end
