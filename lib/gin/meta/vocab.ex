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
  term file (`.eterm`) for common (species-neutral) entries. The optional
  `:eterm_human` and `:eterm_mouse` options load species-specific entries.
  Each entry is either a plain string (canonical only, matched by slug) or a
  `{canonical, [alias, ...]}` tuple (explicit aliases matched case-insensitively
  AND by slug).

  When species eterms are given, `normalize/2` is generated with `:human`,
  `:mouse`, and `:any` dispatch. `normalize/1` always covers the full union.

  The `:obo` option takes a path relative to `priv/` pointing to an OBO 1.2
  ontology file. All `[Term]` entries with `id: CL:` are parsed and merged.
  eterm entries take priority for slug conflicts — manual curation wins.
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

    # Common / base eterm (species-neutral)
    {common_entries, common_path} =
      if eterm = Keyword.get(opts, :eterm) do
        path = Path.join(priv_dir, eterm)
        {Gin.Meta.Vocab.load_eterm!(path), path}
      else
        {[], nil}
      end

    # Human-specific eterm
    {human_eterm_entries, human_eterm_path} =
      if eterm = Keyword.get(opts, :eterm_human) do
        path = Path.join(priv_dir, eterm)
        {Gin.Meta.Vocab.load_eterm!(path), path}
      else
        {[], nil}
      end

    # Mouse-specific eterm
    {mouse_eterm_entries, mouse_eterm_path} =
      if eterm = Keyword.get(opts, :eterm_mouse) do
        path = Path.join(priv_dir, eterm)
        {Gin.Meta.Vocab.load_eterm!(path), path}
      else
        {[], nil}
      end

    # OBO ontology
    {obo_entries, obo_path} =
      if obo = Keyword.get(opts, :obo) do
        path = Path.join(priv_dir, obo)
        {Gin.Ontology.Obo.parse_terms(path), path}
      else
        {[], nil}
      end

    has_species = human_eterm_entries != [] || mouse_eterm_entries != []

    # Union of all entries for normalize/1; eterm sources win over OBO
    all_eterm = common_entries ++ human_eterm_entries ++ mouse_eterm_entries
    all_entries = all_eterm ++ obo_entries

    # Species-filtered entry sets (common + species + OBO)
    human_entries = common_entries ++ human_eterm_entries ++ obo_entries
    mouse_entries = common_entries ++ mouse_eterm_entries ++ obo_entries

    # use_slug: true when any eterm or OBO source is present
    {final_entries, use_slug} =
      cond do
        all_entries != [] -> {all_entries, true}
        true -> {Keyword.fetch!(opts, :entries), false}
      end

    quote bind_quoted: [
            final_entries: final_entries,
            human_entries: human_entries,
            mouse_entries: mouse_entries,
            has_species: has_species,
            use_slug: use_slug,
            common_path: common_path,
            human_eterm_path: human_eterm_path,
            mouse_eterm_path: mouse_eterm_path,
            obo_path: obo_path
          ] do
      @behaviour Gin.Meta.Vocab

      if common_path, do: @external_resource(common_path)
      if human_eterm_path, do: @external_resource(human_eterm_path)
      if mouse_eterm_path, do: @external_resource(mouse_eterm_path)
      if obo_path, do: @external_resource(obo_path)

      @lookup Gin.Meta.Vocab.build_lookup(final_entries)
      @members final_entries |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

      @impl true
      def members, do: @members

      @impl true
      def known?(raw), do: match?({:ok, _}, normalize(raw))

      if use_slug do
        @slug_lookup Gin.Meta.Vocab.build_slug_lookup(final_entries)

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

        if has_species do
          @lookup_human Gin.Meta.Vocab.build_lookup(human_entries)
          @slug_lookup_human Gin.Meta.Vocab.build_slug_lookup(human_entries)
          @lookup_mouse Gin.Meta.Vocab.build_lookup(mouse_entries)
          @slug_lookup_mouse Gin.Meta.Vocab.build_slug_lookup(mouse_entries)

          def normalize(raw, :human) do
            key = String.downcase(raw)

            case Map.get(@lookup_human, key) do
              nil ->
                case Map.get(@slug_lookup_human, Gin.Meta.Vocab.slugify(key)) do
                  nil -> {:unknown, raw}
                  canonical -> {:ok, canonical}
                end

              canonical ->
                {:ok, canonical}
            end
          end

          def normalize(raw, :mouse) do
            key = String.downcase(raw)

            case Map.get(@lookup_mouse, key) do
              nil ->
                case Map.get(@slug_lookup_mouse, Gin.Meta.Vocab.slugify(key)) do
                  nil -> {:unknown, raw}
                  canonical -> {:ok, canonical}
                end

              canonical ->
                {:ok, canonical}
            end
          end

          def normalize(raw, :any), do: normalize(raw)
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
  Map a genome assembly string to a species atom for use with `normalize/2`.

  Returns `:human` for hg* assemblies, `:mouse` for mm* assemblies, and
  `:unknown` for anything else (including nil).
  """
  def assembly_species(assembly) when is_binary(assembly) do
    cond do
      String.starts_with?(assembly, "hg") -> :human
      String.starts_with?(assembly, "mm") -> :mouse
      true -> :unknown
    end
  end

  def assembly_species(_), do: :unknown

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
        Map.put_new(m, String.downcase(a), canonical)
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
