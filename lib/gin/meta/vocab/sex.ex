defmodule Gin.Meta.Vocab.Sex do
  use Gin.Meta.Vocab,
    entries: [
      {"Female", ~w[female F f]},
      {"Male", ~w[male M m]},
      {"Mixed", ~w[mixed]},
      {"Unknown", ~w[unknown NA n/a]}
    ]
end
