# claude-lifeline

> Real-time statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — context health, cost, git state, cache efficiency, and session duration. All in your terminal.

---

## Display modes

Pick how much you want to see. Switch anytime with `claude-lifeline-config`.

**Simple**
```
Claude Sonnet 4.6  ████░░░░░░░░ 33%  ● healthy
```

**Moderate**
```
Claude Sonnet 4.6  ████░░░░░░░░ 33%  ● healthy  ⎇ main
$0.0031 session · 14m
```

**All** _(default)_
```
@you  Claude Sonnet 4.6  ████░░░░░░░░ 33%  ● healthy  ⎇ main*
$0.0001/1k · 24k/200k · cache:16%  $0.0031 session · $1.23 API · 14m
```

**Custom** — choose any combination of data points individually.

---

## Install

```bash
brew tap lokesh2021/claude-lifeline
brew install claude-lifeline
```

That's it. The installer automatically writes the `statusLine` config to `~/.claude/settings.json`. Restart Claude Code and the statusline appears.

### Script install (no Homebrew)

```bash
git clone https://github.com/lokesh2021/claude-lifeline.git
cd claude-lifeline
bash install.sh
```

---

## Commands

| Command | What it does |
|---------|-------------|
| `claude-lifeline-config` | Interactive display mode picker — simple / moderate / all / custom |
| `claude-lifeline-report` | Weekly usage summary in your terminal |

### Weekly report

```
Claude Lifeline — Weekly Report
Mar 14 – Mar 20, 2026
────────────────────────────────────────────────────
Day             Tokens     Cost       Cache%     Sessions
────────────────────────────────────────────────────
Fri Mar 14      142k       $0.44      71%        3
Sat Mar 15      89k        $0.28      68%        2
Sun Mar 16      —          —          —          0
Mon Mar 17      234k       $0.72      74%        5
Tue Mar 18      178k       $0.55      69%        4
Wed Mar 19      45k        $0.14      72%        1
Thu Mar 20      67k        $0.21      65%        2
────────────────────────────────────────────────────
Weekly Total    755k       $2.34      71% avg    17 sessions

Peak day: Mon Mar 17 ($0.72)

Top branches:
  12×  main
   3×  feat/auth
   2×  fix/bug
```

Usage is logged automatically to `~/.claude/.lifeline/YYYY-MM-DD.tsv` as you work — no setup needed.

---

## What each data point means

| Display | What it tells you |
|---------|-------------------|
| `████░░░░░░░░ 33%` | How full your context window is |
| `● healthy` / `● ATTENTION` / `● CHECKPOINT` / `● CRITICAL` / `◉◉ EMERGENCY` | Context health at 0 / 50 / 75 / 90 / 95% |
| `⎇ main*` | Current git branch — `*` means uncommitted changes |
| `$0.0001/1k` | Cost per 1k tokens this session |
| `24k/200k` | Tokens used out of context limit |
| `cache:16%` | Fraction of tokens from prompt cache (higher = cheaper) |
| `$0.0031 session` | Total cost for this Claude Code session |
| `$1.23 API` | Month-to-date API spend (requires Admin API key) |
| `14m` | How long this session has been running |

---

## Configuration

### API spend tracking (optional)

To show month-to-date billing, set an Anthropic Admin API key:

```bash
# ~/.zshrc
export ANTHROPIC_ADMIN_API_KEY="sk-ant-admin01-..."
```

Get one at [console.anthropic.com/settings/admin-keys](https://console.anthropic.com/settings/admin-keys).

### Reconfigure display

```bash
claude-lifeline-config
```

Config is saved to `~/.claude/.lifeline/config` and takes effect after restarting Claude Code.

---

## Dependencies

| Tool | Required | Install |
|------|----------|---------|
| `jq` | Yes | `brew install jq` — handled automatically by Homebrew |
| `gh` | Yes | `brew install gh` — handled automatically by Homebrew |
| `bc` | Yes | Pre-installed on macOS/Linux |
| `curl` | For API spend | Pre-installed |

---

## Troubleshooting

**Statusline not showing?**
Check `~/.claude/settings.json` has the `statusLine` block, then restart Claude Code.

**`jq: command not found`**
`brew install jq`

**GitHub username not showing?**
`gh auth status` — must be authenticated. Cache at `~/.claude/.gh_user_cache` refreshes every 60 min.

**API cost shows $0.00?**
Verify `echo $ANTHROPIC_ADMIN_API_KEY` — key needs Admin permissions. Cache at `~/.claude/.api_cost_cache` refreshes every 5 min.

---

## License

MIT — see [LICENSE](LICENSE)
