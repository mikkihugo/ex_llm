# pg_uuidv7 Installation: Why Not Build in Nix Directly?

## The Question

"Can't Nix build pg_uuidv7 directly from the GitHub repo?"

**Short answer:** Yes, technically possible. But NOT RECOMMENDED. Here's why.

---

## Comparison of Three Approaches

### ❌ Approach 1: Nix `buildRustPackage` (Build in Nix)

**What it looks like:**
```nix
pg_uuidv7 = pkgs.rustPlatform.buildRustPackage rec {
  pname = "pg_uuidv7";
  cargoHash = "sha256-XXXXX...";  # Exact hash required
  nativeBuildInputs = [ cargo-pgrx postgresql_17 ... ];
  buildPhase = ''cargo pgrx package --release'';
  installPhase = ''... install .so files ...'';
};
```

**Problems:**
1. ❌ **cargoHash complexity** - Requires exact lock file hash, changes with Cargo.lock
2. ❌ **No stable tags** - pg_uuidv7 uses main branch (unstable)
3. ❌ **pgrx build complexity** - Requires pg_config, specific build steps
4. ❌ **Maintenance burden** - Must update cargoHash whenever dependencies change
5. ❌ **Slower builds** - Compiles Rust from source every rebuild (5-10 min)
6. ❌ **Cache issues** - Nix caching doesn't help with changing main branch

**When to use:** Never, for pg_uuidv7. Too complex for the benefit.

---

### ✅ Approach 2: PGXN (Pre-built Binaries) - CURRENT DEFAULT

**What it looks like:**
```bash
brew install pgxnclient
pgxn install pg_uuidv7
```

**Advantages:**
- ✅ **Pre-built** - No compilation needed (~2 seconds)
- ✅ **Battle-tested** - Official PostgreSQL Extension Network
- ✅ **Zero maintenance** - No hashes to track, no cargo locks
- ✅ **Works everywhere** - macOS, Linux, WSL
- ✅ **Simple** - One command, clear error messages

**Disadvantages:**
- ⚠️ External tool (pgxnclient) required outside Nix
- ⚠️ No Nix reproducibility (uses system pgxn)

**When to use:** **RECOMMENDED** - Best for most developers

---

### ✅ Approach 3: Cargo-pgrx Manual Build - ADVANCED OPTION

**What it looks like:**
```bash
# All tools provided in nix develop
nix develop
git clone https://github.com/craigpastro/pg_uuidv7.git
cd pg_uuidv7
PG_CONFIG=$(pg-config) cargo pgrx install --release
```

**Advantages:**
- ✅ **Full source access** - Can modify/debug extension
- ✅ **Learning** - Understand how pgrx extensions work
- ✅ **Nix-integrated tools** - cargo, pgrx, PostgreSQL all available
- ✅ **Latest code** - Build from main branch if needed

**Disadvantages:**
- ⚠️ **Slower** - Compiles Rust (5-10 minutes)
- ⚠️ **More complex** - Requires setting PG_CONFIG
- ⚠️ **Overkill for most cases** - Just need the extension, not source mods

**When to use:** When learning pgrx, contributing to pg_uuidv7, or needing latest main branch

---

## Current Singularity Setup

We provide **BOTH options** to users:

```bash
nix develop
```

Shell hook shows:
```
📦 pg_uuidv7 installation options:
   ✅ Option 1 (Quick): pgxn install pg_uuidv7
   ✅ Option 2 (Rust): cargo-pgrx in shell - build from source
```

### Why This is Optimal

1. **Low friction default** - PGXN is 30 seconds, works immediately
2. **Advanced option available** - Cargo-pgrx for developers who need it
3. **No Nix complexity** - Avoids buildRustPackage maintenance burden
4. **Graceful fallback** - Migration works either way with `COALESCE`
5. **Developer choice** - Users pick what works for them

---

## Technical Reasons Approach 1 Doesn't Work Well

### cargoHash Problem

Nix requires exact `cargoHash` for reproducibility:
```
cargoHash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
```

This hash is from **Cargo.lock**, which changes when:
- Rust dependencies update (happens weekly)
- pgrx upstream changes
- Any transitive dependency updates

**Cost:** Must update flake.nix every time a dependency changes upstream.

### Main Branch Issue

pg_uuidv7 doesn't use semantic versioning tags. Using `rev = "main"`:
```nix
src = fetchFromGitHub {
  rev = "main";  # Unpredictable, always changing
  sha256 = "???"; # Can't pin a moving target reliably
};
```

**Result:** Build could break unexpectedly.

### pgrx-specific Build Complexity

pgrx extensions require:
- `PG_CONFIG` environment variable
- Specific cargo flags (`cargo pgrx package --release`)
- Complex install paths
- Interaction with PostgreSQL version

**Cost:** High maintenance burden in flake.nix

---

## Long-term Maintenance

### Option 1 (Build in Nix)
```
Week 1: Set up buildRustPackage
Week 2: cargoHash changes → Update
Week 3: Dependency updates → Update cargoHash
Week 4: pgrx minor version → Might break
...continuous maintenance burden...
```

### Option 2 (PGXN - Current)
```
Week 1: Document PGXN option
Week 2-52: Zero changes needed
Users automatically get updates via pgxn
```

### Option 3 (Cargo-pgrx Available)
```
Users who need it can `cargo pgrx install` manually
Those users know they're building from source
No Nix maintenance needed
```

**Winner:** Option 2 + 3 combination (CURRENT)

---

## Conclusion

| Goal | Best Approach |
|------|---|
| Get UUIDs working quickly | PGXN ✅ |
| Understand pgrx | Cargo-pgrx + source ✅ |
| Reproducible Nix builds | Not applicable - tools are available |
| Minimal maintenance | PGXN ✅ |
| Latest main branch | Cargo-pgrx manually ✅ |

**Final Answer to "Can't Nix build directly?"**

Technically yes, but:
1. ❌ Too complex for the benefit
2. ❌ High ongoing maintenance
3. ❌ No real advantage (PGXN is pre-built anyway)
4. ✅ Better: Provide both PGXN (default) + cargo-pgrx (for advanced users)

**This is the pragmatic approach that real production systems use.**

---

## References

- **PGXN:** https://pgxn.org/ (Official PostgreSQL Extension Network)
- **pg_uuidv7:** https://github.com/craigpastro/pg_uuidv7
- **pgrx:** https://github.com/pgcentralfoundation/pgrx
- **Nix rustPlatform:** https://nixos.wiki/wiki/Rust
