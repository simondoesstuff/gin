# Gin

In a separate repo, we've created a 1D interval intersection search tool, a "genomic search engine" that can perform at trillion scale.
To feed the engine, Gin centralizes intervals and standardizes metadata from track hubs.

Gin is still en route to version 1.0 in elixir. Gin is currently only so ambitious as to support UCSC Genome Browser or track hubs compatible for parsing by the UCSC Genome Browser.

**Gin Responsibilities**

- Pull intervals from external repositories
- Pull and standardize metadata
- Maintain the timestamp of when the cache was last updated
- Send HEAD requests on refresh to conservatively update
- Deduplicate tracks by hashing intervals and merging metadata

### Gin Store

The gin store is a flat list of entries in a track hub. The bulk consists of sub-directories for each track hub source. A source sub-directory contains entries, one per track. A gin store entry is the pair: .json file and genomic interval set file. The entry pair contains all of the information of that track, considering even the entire store. Most track hubs will store contents hierarchically, gin flattens, not capturing the hierarchy; only leaf nodes. If a track hub specifies an entry's metadata using inheritance, gin stores it flat.

**Gin store entry .json**

- sources: { source_name, download_link }[]
- refresh_time
- iv_hash
- metadata: GinMeta

**Gin Meta**

The standardized schema of genomic track descriptions. This is a big type, but it contains at least:

- name
- assembly
- other
- ...

A "source" is a track hub, considered as a list of "targets". A fully qualified target name is in the form `source/name` where the `name` could itself include slashes. In addition to entry data, the gin store contains the **IV hash record** which maps an IV set hash to a target name -- crucial for efficient IV-set deduplication. The gin store guarantees the IV hash record and IV hash in an entry to be consistent -- the IV hash record can be trusted to point to an entry with that IV hash.

### Metadata Transformers

A set of metadata transformers attempt to universally extract and transform data into a known form. Gin has a fixed schema for metadata that it attempts to force alternative representations into. All un-standardized formats should be key-value hierarchies. Non-recognized keys or values are not discarded, but left in the standardized metadata under the `other` key.

### Other

- IV hash collisions are not handled, although it is not quite catastrophic if it occurs. Gin relies on large hashes like SHA-256 to make the chance astronomically low.
