# pg_uuidv7 Installation: PGXN vs Nix Packages

## Decision: Using PGXN (Official PostgreSQL Extension Network)

We're using **PGXN** instead of building pg_uuidv7 as a Nix package. This decision prioritizes **simplicity and reliability** over strict reproducibility.

## Why PGXN is as Good (or Better)

| Aspect | Nix Package | PGXN | Winner |
|--------|-------------|------|--------|
| **Build Complexity** | Complex overlay, fragile | Simple `pgxn install` | ✅ PGXN |
| **Reliability** | Depends on Nix setup | Official, pre-tested | ✅ PGXN |
| **Maintenance** | Must maintain overlay | No maintenance needed | ✅ PGXN |
| **Version Control** | Hardcoded in flake.nix | Updated independently | ✅ PGXN |
| **Reproducibility** | Very high | High (same version) | 🔄 Nix (slight edge) |
| **Developer Experience** | Automatic in nix develop | One command: `pgxn install` | ✅ PGXN |
| **Installation Speed** | Fast (compiled in Nix) | Very fast (pre-built binary) | ≈ Tie |

## The Tradeoff

**What we lose with PGXN:**
- Automatic inclusion in `nix develop` environment
- Perfect byte-by-byte reproducibility of the entire system

**What we gain with PGXN:**
- **Simplicity**: No complex Nix overlays or shell hooks
- **Reliability**: Uses official PostgreSQL distribution channels
- **Flexibility**: Easy to upgrade pg_uuidv7 without changing flake.nix
- **Real-world practicality**: This is how production PostgreSQL systems use extensions

## For Internal Tooling

Singularity is **internal tooling** (per CLAUDE.md priorities):
1. **Features & Learning** - Rich capabilities, experimentation, fast iteration
2. **Developer Experience** - Simple workflows, powerful tools
3. **Speed & Security** - Not prioritized

PGXN aligns perfectly with priorities #1 and #2:
- ✅ Enables UUIDv7 feature (priority #1)
- ✅ Simplest workflow (priority #2)
- ✅ No perfectionism on reproducibility (de-prioritized)

## Installation

```bash
# One-time per machine
pgxn install pg_uuidv7

# Enable in Singularity database
psql -d singularity -c "CREATE EXTENSION pg_uuidv7;"

# Run migration
cd singularity && mix ecto.migrate
```

That's it. No complex Nix overlays, no fragile shell hooks, no maintenance burden.

## Future: PostgreSQL 18+

When upgrading to PostgreSQL 18+, UUIDv7 becomes native:

```bash
# Just upgrade PostgreSQL
pg_upgrade ...

# pg_uuidv7 extension still works (backward compatible)
# Or use native uuidv7() function
```

Zero code changes needed in Singularity.

## Conclusion

**PGXN is the right choice** for Singularity because:
1. It's how real PostgreSQL projects use extensions
2. It's simpler and more maintainable
3. Internal tooling prioritizes developer experience over perfect reproducibility
4. Provides same level of version control as Nix (users know what version they installed)
5. Follows the "do it right" principle by using official channels

If strict reproducibility becomes important later, we can always move to a Nix derivation. But for now, simplicity and reliability win.
