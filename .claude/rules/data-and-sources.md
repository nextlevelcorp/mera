# Game data and sources
- Species, spots, tackle and bait live in `game/data/` as data files with a schema, never in scene scripts.
- Every record has an `id`, an English source name, localisation keys, and either a `source` (URL or citation) or `design_fill: true`.
- Record the licence of every data, art and audio source in `docs/reference_docs.md` before the asset is committed.
- Do not invent real-world facts. If no source exists, label the value a game-design fill, in the data and in the in-game log.
