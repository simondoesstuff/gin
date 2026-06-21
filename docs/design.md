# Gin

In a separate repo, we've created a 1D interval intersection search tool, a "genomic search engine" that can perform at trillion scale.  
To feed the engine, Gin centralizes intervals and metadata from track hubs.

Gin Responsibilities

- Pull intervals from external repositories
- Pull and standardize metadata
- Maintain the timestamp of when the cache was last updated
- Send HEAD requests on refresh to conservatively update
- Deduplicate tracks by hashing intervals and merging metadata

Gin organizes information in the "Gin Store" consisting of:

- Tracks: a pair of files, a .json file and an interval set file
-
