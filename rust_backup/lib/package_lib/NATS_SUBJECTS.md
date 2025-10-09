
### Package Storage (PostgreSQL via Elixir)
```
packages.storage.store           # Store package metadata (via JetStream cache)
packages.storage.get             # Get package metadata (cache-first)
packages.storage.delete          # Delete package
packages.storage.list            # List packages in ecosystem
packages.storage.search          # Search packages by prefix
packages.storage.search_by_tags  # Search packages by tags
packages.storage.stats           # Get storage statistics
packages.storage.get_all         # Get all packages (expensive!)
```

**Storage Architecture:**
```
Rust (NatsStorage)
    ↓ packages.storage.*
JetStream KV (cache, TTL=1h) ← Fast reads!
    ↓ (on cache miss)
Elixir (NatsDatabaseProxy)
    ↓ Ecto
PostgreSQL (source of truth)
```

### Package Collection & Detection
```
packages.registry.collect.npm       # Collect npm package
packages.registry.collect.cargo     # Collect cargo crate
packages.registry.collect.hex       # Collect hex package
packages.registry.detect.frameworks # Detect frameworks in codebase
packages.registry.detect.list       # List all known frameworks
```

### Package Analysis Storage (Context7 on Steroids!)
```
packages.analysis.store             # Store analysis results for package
packages.analysis.get               # Get analysis results for package
packages.analysis.search            # Search packages by analysis criteria
packages.analysis.quality           # Get quality scores for package
packages.analysis.security          # Get security analysis for package
packages.analysis.performance       # Get performance analysis for package
packages.analysis.architecture      # Get architecture analysis for package
packages.analysis.insights          # Get cross-package insights
```
