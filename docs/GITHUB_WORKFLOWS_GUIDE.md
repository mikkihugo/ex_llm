# GitHub Actions Workflow Audit

**Last Updated:** 2025-10-12  
**Status:** ✅ All Critical Issues Fixed + Disk Space Optimized

## Summary of Workflows

This repository has 7 GitHub Actions workflows:

1. **ci-elixir.yml** - Build and test Elixir + Gleam code
2. **nix-setup.yml** - Reusable workflow for Nix environment setup
3. **copilot-setup-steps.yml** - Setup environment for GitHub Copilot
4. **deploy.yml** - Deploy to Fly.io
5. **fly-oci-deploy.yml** - Deploy Seed Agent OCI image
6. **claude-pr-fix.yml** - Auto-fix PRs using Claude Code
7. **claude-pr-review.yml** - Auto-review PRs using Claude Code

## Issues Found and Fixed

### Critical Issues (Fixed)

#### 1. ✅ Warmup Compile Step Ordering (copilot-setup-steps.yml)
**Issue:** The "Warm-up compile" step ran BEFORE dependencies were installed  
**Impact:** Compile would fail because `mix deps.get` hadn't been run yet  
**Fix:** Moved warmup compile step to run after "Install Elixir dependencies"  
**Lines Changed:** 72-86

#### 2. ✅ Secret Check Syntax (fly-oci-deploy.yml)
**Issue:** Line 27 used incorrect syntax: `if: secrets.CACHIX_AUTH_TOKEN != ''`  
**Impact:** Condition would always be truthy, even when secret is missing  
**Fix:** Changed to: `if: ${{ secrets.CACHIX_AUTH_TOKEN != '' }}`  
**Also Fixed:** Standardized cachix cache name from "singularity" to "mikkihugo"

#### 3. ✅ Workflow Reference (claude-pr-review.yml)
**Issue:** Line 24 used incorrect workflow reference to external repo  
**Impact:** Workflow would fail when trying to call nix-setup.yml  
**Fix:** Replaced composite workflow call with direct Nix setup steps  
**Details:** Removed the incorrect `uses: mikkihugo/singularity-incubation/.github/workflows/nix-setup.yml@master` and replaced with inline Nix + Cachix setup

#### 4. ✅ Outdated Action Versions (deploy.yml)
**Issue:** Using old action versions (checkout@v3, install-nix-action@v22)  
**Impact:** Missing security fixes and new features  
**Fix:** Updated to latest versions matching other workflows

#### 5. ✅ Disk Space Issues (All Nix Workflows)
**Issue:** GitHub Actions runners provide only ~20GB of free disk space, insufficient for large Nix builds  
**Impact:** Workflows could fail with "no space left on device" errors during Nix builds  
**Fix:** Integrated "Nothing But Nix" action to reclaim 65-130GB of disk space  
**Details:** Added `wimpysworld/nothing-but-nix@main` action before Nix installation in all workflows that use Nix

#### 6. ✅ Incorrect Workflow Calls (copilot-setup-steps.yml, fly-oci-deploy.yml)
**Issue:** Trying to use reusable workflow `nix-setup.yml` as a step instead of a job  
**Impact:** Workflows would fail because workflows can only be called as jobs, not steps  
**Fix:** Replaced workflow calls with inline Nix setup steps including Nothing But Nix action

## Secrets Required

### Required Secrets (Must Set):

1. **FLY_API_TOKEN** - For Fly.io deployments
   ```bash
   # Get token
   fly auth login
   fly auth token
   
   # Set in GitHub
   gh secret set FLY_API_TOKEN --body "YOUR_TOKEN_HERE"
   ```

2. **CLAUDE_CODE_OAUTH_TOKEN** - For Claude Code integration
   ```bash
   # Get token (requires Claude Code CLI)
   claude setup-token
   
   # Set in GitHub
   gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "YOUR_TOKEN_HERE"
   ```

### Optional Secrets (Recommended):

3. **CACHIX_AUTH_TOKEN** - For pushing to Nix cache (speeds up builds)
   ```bash
   # Create account at https://app.cachix.org
   # Create cache named "mikkihugo" (or use existing)
   # Generate auth token
   
   # Set in GitHub
   gh secret set CACHIX_AUTH_TOKEN --body "YOUR_TOKEN_HERE"
   ```

### Not Needed in GitHub Actions:

4. **AGE_SECRET_KEY** - Only needed in Fly.io secrets for runtime decryption
   - Stored in Fly.io: `flyctl secrets set AGE_SECRET_KEY="$(cat .age-key.txt)"`
   - NOT needed in GitHub Actions

5. **GITHUB_TOKEN** - Automatically provided by GitHub Actions
   - No setup required

## Workflow Details

### 1. ci-elixir.yml
**Purpose:** Build and test Elixir + Gleam code  
**Triggers:** Push to main/master, pull requests, manual dispatch  
**Status:** ✅ Working  
**Secrets:** Inherits CACHIX_AUTH_TOKEN from nix-setup.yml

**Steps:**
1. Calls nix-setup reusable workflow
2. Checkout code
3. Install Nix + Cachix
4. Restore caches (Mix/Hex/Moon)
5. Fetch dependencies
6. Compile (Elixir + Gleam)
7. Format & Lint (mix format, credo)
8. Security audit (mix deps.audit)
9. Run tests

**Recommendations:**
- ✅ Good separation of concerns
- ✅ Proper caching strategy
- ✅ Security audit included

### 2. nix-setup.yml
**Purpose:** Reusable workflow for Nix environment setup  
**Type:** Reusable workflow (workflow_call)  
**Status:** ✅ Working  
**Secrets:** CACHIX_AUTH_TOKEN (optional)

**Parameters:**
- `cachix_push` (boolean) - Build and push to Cachix cache
- `cache_key_prefix` (string) - Prefix for cache keys

**Steps:**
1. Checkout code
2. **Maximize disk space for Nix (Nothing But Nix action)**
3. Install Nix with flakes
4. Use Cachix (pull; push if token available)
5. Run diagnostics
6. Show toolchain versions
7. Cache Mix/Hex, Moon, Bun
8. Build and push dev shell (if enabled)
9. Build and push Nix packages (if enabled)

**Recommendations:**
- ✅ Nothing But Nix action reclaims 65-130GB for Nix store
- Consider adding timeouts to build steps
- Monitor cache hit rates

### 3. copilot-setup-steps.yml
**Purpose:** Setup environment for GitHub Copilot  
**Triggers:** Manual dispatch, changes to this workflow file  
**Status:** ✅ Fixed (was broken)  
**Secrets:** Inherits CACHIX_AUTH_TOKEN from nix-setup.yml

**Steps (Corrected Order):**
1. Calls nix-setup reusable workflow
2. Checkout code
3. Install Nix + Cachix
4. Restore caches
5. Install dependencies via Nix
6. **Install Elixir dependencies** (mix deps.get)
7. **Warm-up compile** (MOVED HERE - was running too early)
8. Install JavaScript dependencies (bun install)
9. Verify setup

**Previous Issue:** Warmup compile ran before deps were installed  
**Fix Applied:** Reordered steps to install deps first

### 4. deploy.yml
**Purpose:** Deploy to Fly.io  
**Triggers:** Push to main, manual dispatch  
**Status:** ✅ Updated  
**Secrets:** FLY_API_TOKEN

**Steps:**
1. Checkout code
2. Install Nix
3. Setup flyctl
4. Build with Nix (singularity-integrated)
5. Deploy to Fly.io

**Recent Changes:**
- Updated checkout action v3 → v4.2.2
- Updated install-nix-action v22 → v31

**Notes:**
- AGE_SECRET_KEY is in Fly.io secrets, not passed in workflow

### 5. fly-oci-deploy.yml
**Purpose:** Deploy Seed Agent OCI image  
**Triggers:** Push to main, manual dispatch  
**Status:** ✅ Fixed  
**Secrets:** FLY_API_TOKEN, CACHIX_AUTH_TOKEN (optional)

**Steps:**
1. Checkout code
2. Install Nix + Cachix
3. Build OCI image
4. Install podman and flyctl
5. Login to Fly registry
6. Push image to registry
7. Deploy

**Recent Changes:**
- Fixed secret check syntax (line 27)
- Standardized cachix name to "mikkihugo"

### 6. claude-pr-fix.yml
**Purpose:** Auto-fix PRs using Claude Code  
**Triggers:** Issue comment containing "@claude-fix"  
**Status:** ✅ Fixed (was broken)
**Secrets:** CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN

**Steps:**
1. Get PR branch details
2. Checkout PR branch
3. Install Bun
4. Get PR diff and comment instructions
5. Run Claude Code to generate fixes (with proper JSON handling)
6. Apply fixes (parse JSON output with error handling)
7. Commit and push (if --auto-apply flag used)

**Previous Issues:**
- ❌ JSON parsing was broken (tried to parse natural language as JSON)
- ❌ No error handling for invalid Claude responses
- ❌ Used wrong credentials file format

**Fixes Applied:**
- ✅ Fixed Claude credentials file format (`~/.claude/.credentials.json`)
- ✅ Added proper JSON extraction and validation
- ✅ Handle markdown code blocks in Claude's response
- ✅ Added error handling and graceful degradation
- ✅ Fixed heredoc variable substitution
- ✅ Better logging for debugging

**Warnings:**
- Experimental feature, use with caution
- Auto-apply can be dangerous - review fixes first
- JSON parsing is simplified
- No rate limiting

**Usage:**
```
@claude-fix Please fix the linting errors
@claude-fix --auto-apply Fix the test failures
```

### 7. claude-pr-review.yml
**Purpose:** Auto-review PRs using Claude Code  
**Triggers:** Issue comment containing "@claude"  
**Status:** ✅ Fixed  
**Secrets:** CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN

**Steps:**
1. Checkout PR
2. Setup Nix + Cachix (inline, not composite workflow)
3. Verify environment
4. Install AI server tools (bun install)
5. Run Claude Code review
6. Post review as comment
7. Auto-merge if approved (optional)
8. Tag Copilot if changes requested

**Recent Changes:**
- Fixed workflow reference (removed incorrect composite call)
- Added inline Nix setup steps

**Warnings:**
- Auto-merge feature could merge PRs without human review
- No rate limiting
- Consider requiring additional approval for merges

**Usage:**
```
@claude Review this PR
@claude Check for security issues
```

## Workflow Dependencies

```
ci-elixir.yml
  └── calls: nix-setup.yml (with cachix_push=true)

copilot-setup-steps.yml
  └── inline Nix setup (includes Nothing But Nix)

claude-pr-review.yml
  └── inline Nix setup (includes Nothing But Nix)

deploy.yml
  └── standalone (includes Nothing But Nix)

fly-oci-deploy.yml
  └── inline Nix setup (includes Nothing But Nix)

claude-pr-fix.yml
  └── standalone (uses Bun, no Nix)
```

## Action Versions Used

| Action | Version | SHA/Tag | Notes |
|--------|---------|---------|-------|
| actions/checkout | v4.2.2 | 11bd71901bbe5b1630ceea73d27597364c9af683 | Latest stable |
| wimpysworld/nothing-but-nix | main | - | Reclaims 65-130GB disk space |
| cachix/install-nix-action | v31 | a809471b5c7c913aa67bec8f459a11a0decc3fce | Latest |
| cachix/cachix-action | v15 | ad2ddac53f961de1989924296a1f236fcfbaa4fc | Latest |
| actions/cache | v4.2.2 | d4323d4df104b026a6aa633fdb11d772146be0bf | Latest |
| oven-sh/setup-bun | v2 | - | Latest (claude-pr-fix) |
| superfly/flyctl-actions/setup-flyctl | master | - | Tracking master |

## Caching Strategy

### Nix Store
- Handled by Cachix (cache name: "mikkihugo")
- Configured in all workflows that use Nix
- Pushes to cache only when `cachix_push=true` and token is set

### Mix/Hex Dependencies
```yaml
path: |
  singularity_app/.mix
  singularity_app/.hex
  singularity_app/deps
  singularity_app/_build
  .moon/cache
  llm-server/node_modules
```

**Cache Key Pattern:**
```
{prefix}-{os}-{mix.lock-hash}-{moon.yml-hash}-{bun.lock-hash}
```

**Example:**
```
ci-otp28-elixir1184-Linux-abc123-def456-ghi789
```

### Cache Prefixes by Workflow:
- ci-elixir: `ci-otp28-elixir1184`
- copilot-setup-steps: `copilot-otp28-elixir1184`
- nix-setup: configurable via `cache_key_prefix` input

## Disk Space Optimization

### Nothing But Nix Action

All workflows that use Nix now include the "Nothing But Nix" action to maximize available disk space for the Nix store.

**Problem:** GitHub Actions runners provide only ~20GB of free disk space, which is often insufficient for large Nix builds.

**Solution:** The `wimpysworld/nothing-but-nix@main` action reclaims 65-130GB of disk space by:
- Removing unnecessary pre-installed software (Docker images, SDKs, etc.)
- Creating a large /nix volume from available space
- Dynamically expanding the volume during workflow execution

**Impact:**
- ✅ Prevents "no space left on device" errors during Nix builds
- ✅ Allows building large Nix packages without running out of space
- ✅ Improves CI reliability for complex NixOS configurations

**Usage in workflows:**
```yaml
- name: Maximize disk space for Nix
  uses: wimpysworld/nothing-but-nix@main

- name: Install Nix
  uses: cachix/install-nix-action@v31
```

**Applied to:**
- ✅ nix-setup.yml (reusable workflow)
- ✅ copilot-setup-steps.yml
- ✅ deploy.yml
- ✅ fly-oci-deploy.yml
- ✅ claude-pr-review.yml

## Security Considerations

### Secret Handling
✅ All secrets use GitHub's encrypted secrets  
✅ Secrets are not logged or exposed in workflow output  
✅ Token masking is automatic for GITHUB_TOKEN  
⚠️ Manual token redaction in debug output (nix-setup.yml line 26)

### Auto-Merge/Auto-Apply Features
⚠️ claude-pr-review.yml can auto-merge PRs if Claude approves  
⚠️ claude-pr-fix.yml can auto-apply fixes with --auto-apply flag  
🔒 Recommendation: Require human approval for production branches

### Permissions
| Workflow | Permissions |
|----------|-------------|
| ci-elixir.yml | Default (read) |
| nix-setup.yml | Default (read) |
| copilot-setup-steps.yml | contents: read |
| deploy.yml | Default (read) + FLY_API_TOKEN |
| fly-oci-deploy.yml | contents: read, id-token: write |
| claude-pr-fix.yml | contents: write, pull-requests: write |
| claude-pr-review.yml | contents: write, pull-requests: write |

## Troubleshooting

### Workflow Fails with "Dependencies not found"
**Cause:** Warmup compile ran before deps installed (fixed)  
**Solution:** Update to latest copilot-setup-steps.yml

### Cachix Push Fails
**Cause:** CACHIX_AUTH_TOKEN not set or incorrect  
**Solution:**
```bash
gh secret set CACHIX_AUTH_TOKEN --body "YOUR_TOKEN_HERE"
```

### Claude Workflows Fail
**Cause:** CLAUDE_CODE_OAUTH_TOKEN not set  
**Solution:**
```bash
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "YOUR_TOKEN_HERE"
```

### Deploy Fails with "Unauthorized"
**Cause:** FLY_API_TOKEN not set or expired  
**Solution:**
```bash
fly auth login
fly auth token
gh secret set FLY_API_TOKEN --body "YOUR_TOKEN_HERE"
```

### Nix Build Fails on Ubuntu Runner
**Cause:** Nix not properly configured  
**Solution:** All workflows now use install-nix-action v31 with proper config

## Monitoring

### Recommended Checks:
- [ ] Monitor workflow success rates
- [ ] Check cache hit rates (Mix/Hex and Cachix)
- [ ] Review auto-merge/auto-apply usage
- [ ] Audit Claude API usage (rate limits)
- [ ] Monitor Fly.io deployment success

### Metrics to Track:
- Average build time (should improve with caching)
- Cache hit rate (target: >80%)
- Test coverage (tracked in ci-elixir.yml)
- Deployment frequency
- Failed workflow rate

## Future Improvements

### Short Term:
- [ ] Add error handling to Claude workflows
- [ ] Implement rate limiting for Claude API calls
- [ ] Add workflow run notifications (Slack/Discord)
- [ ] Improve JSON parsing in claude-pr-fix.yml

### Medium Term:
- [ ] Add integration tests for workflows
- [ ] Create workflow templates for new services
- [ ] Add deployment rollback automation
- [ ] Implement canary deployments

### Long Term:
- [ ] Add performance benchmarking workflow
- [ ] Implement automated dependency updates
- [ ] Add security scanning workflow
- [ ] Create custom GitHub Actions for common patterns

## Related Documentation

- [QUICKSTART.md](./setup/QUICKSTART.md) - General setup guide
- [CREDENTIALS_ENCRYPTION.md](./setup/CREDENTIALS_ENCRYPTION.md) - Encryption setup
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Nix Flakes Guide](https://nixos.wiki/wiki/Flakes)
- [Cachix Documentation](https://docs.cachix.org/)
- [Fly.io Deployment](https://fly.io/docs/hands-on/install-flyctl/)

## Changelog

### 2025-10-11 - Initial Audit
- ✅ Fixed warmup compile step ordering in copilot-setup-steps.yml
- ✅ Fixed secret check syntax in fly-oci-deploy.yml
- ✅ Fixed workflow reference in claude-pr-review.yml
- ✅ Updated action versions in deploy.yml
- ✅ Standardized cachix cache name to "mikkihugo"
- 📝 Created comprehensive audit documentation
