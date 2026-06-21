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
  """

  @doc "Return `{:ok, canonical}` or `{:unknown, raw}` for the given raw string."
  @callback normalize(raw :: String.t()) :: {:ok, String.t()} | {:unknown, String.t()}

  @doc "Return all canonical members of this vocabulary."
  @callback members() :: [String.t()]

  @doc "True if the raw string normalizes to a known value."
  @callback known?(raw :: String.t()) :: boolean()

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Gin.Meta.Vocab

      # entries is [{canonical, [alias, ...]}, ...]
      @entries Keyword.fetch!(opts, :entries)

      @lookup Enum.reduce(@entries, %{}, fn {canonical, aliases}, acc ->
                all = [canonical | aliases]

                Enum.reduce(all, acc, fn a, m ->
                  Map.put(m, String.downcase(a), canonical)
                end)
              end)

      @members Enum.map(@entries, &elem(&1, 0))

      @impl true
      def members, do: @members

      @impl true
      def known?(raw), do: match?({:ok, _}, normalize(raw))

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
