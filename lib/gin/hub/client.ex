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
    with {:ok, text} <- fetch_with_includes(trackdb_url) do
      {:ok, TrackDb.parse_and_resolve(text)}
    end
  end

  # Fetch a trackDb file and recursively inline any `include` directives.
  defp fetch_with_includes(url, depth \\ 0)
  defp fetch_with_includes(_url, depth) when depth >= 8, do: {:error, :include_depth_exceeded}

  defp fetch_with_includes(url, depth) do
    with {:ok, text} <- get(url) do
      base = base_url(url)

      expanded =
        text
        |> String.split("\n")
        |> Enum.flat_map(fn line ->
          trimmed = String.trim(line)

          if String.starts_with?(trimmed, "include ") do
            path = String.slice(trimmed, 8..-1//1) |> String.trim()
            included_url = "#{base}/#{path}"

            case fetch_with_includes(included_url, depth + 1) do
              {:ok, included_text} -> String.split(included_text, "\n")
              {:error, _} -> []
            end
          else
            [line]
          end
        end)
        |> Enum.join("\n")

      {:ok, expanded}
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
    # retry: false so we fall through to curl immediately on transport errors
    # rather than waiting through 3 retries (common for TLS-filtered hosts)
    case Req.get(url, retry: false) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_status, status, url}}
      {:error, %Req.TransportError{}} -> get_via_curl(url)
      {:error, reason} -> {:error, {reason, url}}
    end
  end

  defp get_via_curl(url) do
    case System.cmd("curl", ["-s", "--fail", "-L", url], stderr_to_stdout: false) do
      {body, 0} -> {:ok, body}
      {_, code} -> {:error, {:curl_exit, code, url}}
    end
  end

  defp base_url(hub_url) do
    uri = URI.parse(hub_url)
    %{uri | path: Path.dirname(uri.path)} |> URI.to_string()
  end
end
