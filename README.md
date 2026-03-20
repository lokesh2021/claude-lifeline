# claude-lifeline

A real-time statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows context usage, cost, git state, cache efficiency, and session duration — all inside your terminal.

## What it looks like

```
@lokesh2021 | Claude Sonnet 4.6 | ████░░░░░░░░ 33% | ● healthy | ⎇ main*
$0.0031/1k · 45k/200k · cache:67%  $0.0412 session · $1.23 API · 14m
```

**Row 1** — GitHub user · model · context bar + % · health status · git branch (`*` = dirty)
**Row 2** — cost/1k · tokens used/limit · cache hit rate · session cost · API spend · elapsed time

## Install via Homebrew

```bash
brew tap lokesh2021/claude-lifeline
brew install claude-lifeline
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "claude-lifeline"
  }
}
```

Restart Claude Code — done.

## Install via script (no Homebrew)

```bash
git clone https://github.com/lokesh2021/claude-lifeline.git
cd claude-lifeline
bash install.sh
```

The installer copies `statusline.sh` to `~/.claude/statusline.sh`, merges the `statusLine` config into `~/.claude/settings.json`, and optionally writes env vars to your shell profile.

## Configuration

Optional — set in your `.zshrc` / `.bashrc`:

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_ADMIN_API_KEY` | Admin API key for month-to-date spend tracking |

```bash
# ~/.zshrc
export ANTHROPIC_ADMIN_API_KEY="sk-ant-admin01-..."
```

## Features

- **Context bar** — color-coded fill (green → yellow → orange → red) based on Claude's context management spec thresholds
- **Health status** — `healthy` / `ATTENTION` / `CHECKPOINT` / `CRITICAL` / `EMERGENCY` at 50/75/90/95%
- **Cache hit rate** — `cache:67%` shows what fraction of tokens came from prompt cache (lower cost)
- **Git branch + dirty indicator** — `⎇ main*` — `*` appears when there are uncommitted changes
- **Session duration** — elapsed time formatted as `8s`, `42m`, `1h23m`
- **Real-time cost** — per-1k-token rate and session total
- **API spend** — month-to-date billing via Anthropic Admin API (optional, cached 5 min)
- **GitHub identity** — shows your `@username` from `gh` CLI (cached 60 min)

## Context rot thresholds

Based on the Claude Opus 4.6 Context Management Spec:

| % used | Color | Status |
|--------|-------|--------|
| 0–49% | green | `● healthy` |
| 50–74% | yellow | `● ATTENTION` |
| 75–89% | orange | `● CHECKPOINT` |
| 90–94% | red | `● CRITICAL` |
| 95%+ | red bg | `◉◉ EMERGENCY` |

## Dependencies

| Tool | Required | Install |
|------|----------|---------|
| `jq` | Yes | `brew install jq` |
| `gh` | Yes | `brew install gh` |
| `bc` | Yes | Pre-installed on macOS/Linux |
| `curl` | For API spend | Pre-installed |

Homebrew install handles `jq` and `gh` automatically.

## Troubleshooting

**Statusline not showing?**
- Check `~/.claude/settings.json` has the `statusLine` block
- Restart Claude Code after changes

**`jq: command not found`**
- `brew install jq`

**API cost shows $0.00?**
- Verify `echo $ANTHROPIC_ADMIN_API_KEY` — needs Admin permissions
- Cache lives at `~/.claude/.api_cost_cache`, refreshes every 5 min

**GitHub username not showing?**
- `gh auth status` — must be authenticated
- Cache at `~/.claude/.gh_user_cache`, refreshes every 60 min

## License

MIT — see [LICENSE](LICENSE)
