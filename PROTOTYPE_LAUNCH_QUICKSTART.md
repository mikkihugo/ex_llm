# Prototype Launch Quickstart

**Quick reference for getting Singularity running** - See [PROTOTYPE_LAUNCH_READINESS.md](PROTOTYPE_LAUNCH_READINESS.md) for full details.

---

## ✅ Pre-Flight Checklist (5 minutes)

### System Requirements
- [ ] Nix installed (`nix --version`)
- [ ] direnv installed (optional but recommended)
- [ ] Git repository cloned

### Initial Setup
```bash
cd /path/to/singularity-incubation
nix develop  # or: direnv allow
```

---

## 🚀 Launch Sequence (30 minutes)

### Step 1: Database Setup (5 min)
```bash
./scripts/setup-database.sh
```
**Verify:** `psql singularity -c '\dt'` shows tables

### Step 2: Generate Secrets (1 min)
```bash
cd singularity
SECRET=$(mix phx.gen.secret)
cat > ../.env <<EOF
SECRET_KEY_BASE=$SECRET
DATABASE_URL=ecto://postgres:postgres@localhost/singularity
PORT=3000
AI_SERVER_URL=http://localhost:3000
EOF
cd ..
```
**Verify:** `cat .env` shows variables

### Step 3: Install Dependencies (10 min)
```bash
# Elixir
cd singularity
mix deps.get
mix compile

# AI Server
cd ../llm-server
bun install
cd ..
```
**Verify:** Both `mix compile` and `bun install` succeed

### Step 4: Start Services (2 min)
```bash
./start-all.sh
```
**Verify:** Check output for ✅ marks

### Step 5: Verify Running (2 min)
```bash
# Check services
curl http://localhost:4000/health  # Elixir
curl http://localhost:3000/health  # AI Server

# Check NATS
pgrep -x nats-server

# Check PostgreSQL
pg_isready
```
**Verify:** All commands succeed

---

## 🎯 Success Criteria

You have a working prototype when:

✅ All services respond to health checks  
✅ Database accepts queries  
✅ NATS is running  
✅ Logs show no critical errors  

---

## 🐛 Quick Troubleshooting

### "Command not found" errors
**Fix:** Run `nix develop` or `direnv allow`

### PostgreSQL connection failed
**Check:** `pg_isready` - if fails, restart Nix shell

### AI Server won't start
**Check:** `which bun` - should be in `/nix/store/...`

### Port already in use
**Fix:** 
```bash
./stop-all.sh
./start-all.sh
```

### Still stuck?
**Check logs:**
```bash
tail -f logs/nats.log
tail -f logs/elixir.log
tail -f logs/llm-server.log
```

---

## 📊 Post-Launch (Optional)

### Add AI Provider (5 min)
```bash
# FREE option - Gemini
gcloud auth application-default login

# OR add to .env:
# CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-xxxxx
# GH_TOKEN=ghp_xxxxx
```

### Import Knowledge Base (10 min)
```bash
cd singularity
mix knowledge.migrate
moon run templates_data:embed-all
```

### Test AI Features (5 min)
```bash
cd singularity
iex -S mix
```
```elixir
# In IEx:
Singularity.Knowledge.ArtifactStore.stats()
Singularity.LLM.Service.chat("gemini-2.5-pro", [
  %{role: "user", content: "Hello, test"}
])
```

---

## 🔄 Daily Operations

### Start System
```bash
nix develop  # or: direnv allow
./start-all.sh
```

### Stop System
```bash
./stop-all.sh
```

### Check Status
```bash
# Services
curl localhost:4000/health
curl localhost:3000/health

# Processes
pgrep -f "beam|nats-server|bun"

# Logs
ls -lh logs/
```

### Update Code
```bash
cd singularity
mix deps.get
mix compile
cd ../llm-server
bun install
cd ..
./stop-all.sh
./start-all.sh
```

---

## 📝 Notes

- **Always run in Nix shell** - All tools are provided by Nix
- **PostgreSQL auto-starts** - When entering Nix shell
- **Logs in `logs/` directory** - Check for errors
- **One database for all** - `singularity` (dev/test/prod)
- **AI providers optional** - System runs without, but no LLM features

---

## 🆘 Emergency Recovery

If everything breaks:

```bash
# 1. Stop all services
./stop-all.sh

# 2. Clean build artifacts
cd singularity
mix clean
rm -rf _build deps
cd ../llm-server
rm -rf node_modules
cd ..

# 3. Restart Nix shell
exit  # Exit current shell
nix develop  # Re-enter

# 4. Re-run setup
./scripts/setup-database.sh
cd singularity
mix deps.get
mix compile
cd ../llm-server
bun install
cd ..

# 5. Start fresh
./start-all.sh
```

---

## ✅ Launch Complete!

**You now have a working Singularity prototype running locally.**

**Next:** See [PROTOTYPE_LAUNCH_READINESS.md](PROTOTYPE_LAUNCH_READINESS.md) for:
- Feature completeness details
- Known issues and workarounds
- Production hardening steps
- Full documentation links

**Enjoy your autonomous AI development environment! 🎉**
