defmodule Gin.Meta.Vocab do
  @moduledoc """
  Behaviour for closed and semi-open controlled vocabularies.

  Each vocab module defines a canonical set of values and optional aliases.
  `normalize/1` maps raw strings (case-insensitive, alias-aware) to their
  canonical form, or returns `{:unknown, raw}` when the value is not in the
  whitelist.

  Callers that receive `{:unknown, raw}` should leave the field as the raw
  string value and log the unrecognized token — the whitelist should then be
  extended for the next iteration.

  ## Entry formats

  The `:entries` option (for small inline vocabs) takes a list of
  `{canonical, [alias, ...]}` tuples. Matching is case-insensitive exact.

  The `:eterm` option takes a path relative to `priv/` pointing to an Erlang
  term file (`.eterm`). Each entry is either a plain string (canonical only,
  matched by slug) or a `{canonical, [alias, ...]}` tuple (explicit aliases
  matched case-insensitively AND by slug). For large open-ended vocabs like
  cell type and tissue, slug matching covers common separator/case variants
  without requiring exhaustive alias lists.
  """

  @doc "Return `{:ok, canonical}` or `{:unknown, raw}` for the given raw string."
  @callback normalize(raw :: String.t()) :: {:ok, String.t()} | {:unknown, String.t()}

  @doc "Return all canonical members of this vocabulary."
  @callback members() :: [String.t()]

  @doc "True if the raw string normalizes to a known value."
  @callback known?(raw :: String.t()) :: boolean()

  # Compute priv directory relative to this file at compile time so it works
  # regardless of cwd. Goes up from lib/gin/meta/ to project root, then priv/.
  @priv_dir Path.expand("../../../priv", __DIR__)

  defmacro __using__(opts) do
    priv_dir = @priv_dir

    {entries, eterm_path, use_slug} =
      cond do
        eterm = Keyword.get(opts, :eterm) ->
          path = Path.join(priv_dir, eterm)
          terms = Gin.Meta.Vocab.load_eterm!(path)
          {terms, path, true}

        true ->
          {Keyword.fetch!(opts, :entries), nil, false}
      end

    quote bind_quoted: [entries: entries, eterm_path: eterm_path, use_slug: use_slug] do
      @behaviour Gin.Meta.Vocab

      if eterm_path, do: @external_resource(eterm_path)

      @lookup Gin.Meta.Vocab.build_lookup(entries)
      @members Enum.map(entries, &elem(&1, 0))

      @impl true
      def members, do: @members

      @impl true
      def known?(raw), do: match?({:ok, _}, normalize(raw))

      if use_slug do
        @slug_lookup Gin.Meta.Vocab.build_slug_lookup(entries)

        @impl true
        def normalize(raw) do
          key = String.downcase(raw)

          case Map.get(@lookup, key) do
            nil ->
              case Map.get(@slug_lookup, Gin.Meta.Vocab.slugify(key)) do
                nil -> {:unknown, raw}
                canonical -> {:ok, canonical}
              end

            canonical ->
              {:ok, canonical}
          end
        end
      else
        @impl true
        def normalize(raw) do
          case Map.get(@lookup, String.downcase(raw)) do
            nil -> {:unknown, raw}
            canonical -> {:ok, canonical}
          end
        end
      end
    end
  end

  @doc """
  Convert a string to a lookup slug: lowercase, collapse non-alphanumeric runs
  to a single underscore, trim leading/trailing underscores.

  Used to match separator/case variants without explicit alias lists, e.g.
  "Brain Hippocampus Middle", "brain-hippocampus-middle", and
  "Brain_Hippocampus_Middle" all slug to "brain_hippocampus_middle".
  """
  def slugify(s) do
    s
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  @doc "Build a case-insensitive exact lookup map from `{canonical, [aliases]}` entries."
  def build_lookup(entries) do
    Enum.reduce(entries, %{}, fn {canonical, aliases}, acc ->
      Enum.reduce([canonical | aliases], acc, fn a, m ->
        Map.put(m, String.downcase(a), canonical)
      end)
    end)
  end

  @doc "Build a slug-based lookup map from `{canonical, [aliases]}` entries."
  def build_slug_lookup(entries) do
    Enum.reduce(entries, %{}, fn {canonical, aliases}, acc ->
      Enum.reduce([canonical | aliases], acc, fn a, m ->
        Map.put_new(m, slugify(a), canonical)
      end)
    end)
  end

  @doc "Load and parse an Erlang term file, returning `{canonical, [aliases]}` pairs."
  def load_eterm!(path) do
    case :file.consult(String.to_charlist(path)) do
      {:ok, [terms]} -> parse_eterm_terms(terms)
      {:error, reason} -> raise "Failed to load vocab file #{path}: #{inspect(reason)}"
    end
  end

  @doc """
  Parse raw Erlang terms from a `.eterm` file into `{canonical, [aliases]}` pairs.

  Accepts:
    - A charlist or binary `"Canonical Name"` (slug-matched only, no aliases)
    - A tuple `{"Canonical", ["Alias1", "Alias2"]}` (explicit aliases)
  """
  def parse_eterm_terms(terms) do
    Enum.map(terms, fn
      s when is_list(s) ->
        {List.to_string(s), []}

      s when is_binary(s) ->
        {s, []}

      {canonical, aliases} ->
        {to_eterm_string(canonical),
         aliases |> List.wrap() |> Enum.map(&to_eterm_string/1)}
    end)
  end

  defp to_eterm_string(s) when is_list(s), do: List.to_string(s)
  defp to_eterm_string(s) when is_binary(s), do: s
end
