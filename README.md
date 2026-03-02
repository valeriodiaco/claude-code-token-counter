# Claude Code Token Counter

Track token usage and costs across Claude Code sessions. Logs every interaction to a JSONL file with input/output tokens, cache metrics, cost, duration, and turn count.

Pairs well with [claude-code-multi-account](https://github.com/valeriodiaco/claude-code-multi-account) for tracking usage across multiple accounts.

## Why

Claude Code's `--output-format json` includes detailed token metrics in its output, but they're buried in JSON and lost when the session ends. This tool captures them automatically into a persistent JSONL log that you can query, aggregate, and analyze.

Use cases:
- **Cost tracking**: know exactly how much each batch job costs
- **Budget monitoring**: track daily/weekly token burn rates
- **Optimization**: identify high-cost sessions, measure cache hit rates
- **Accounting**: per-tag breakdowns for different projects or phases

## Install

```bash
git clone https://github.com/valeriodiaco/claude-code-token-counter.git
cd claude-code-token-counter
./install.sh
```

Installs `claude-token-log`, `claude-token-report`, and `token-logger.lib.sh` to `~/.local/bin/`.

## Quick start

### Log a session

```bash
# Just prefix your claude command with claude-token-log:
claude-token-log -p "explain this function"

# Tag sessions for later filtering:
claude-token-log --tag "refactoring" -- --model claude-opus-4-6 -p "refactor auth module"

# Specify where to write the log:
claude-token-log --log /tmp/my-usage.jsonl -p "hello"
```

Every session appends one line to `./token_usage.jsonl` (or your custom path).

### View a report

```bash
claude-token-report
```

```
  Token Usage Report
  Period: 2026-03-01T10:00:00 → 2026-03-02T22:30:00

  GROUP                SESSIONS      INPUT     OUTPUT    CACHE R       COST   DURATION   TURNS
  ------------------------------------------------------------------------------------------
  all                        24      2.1M      380K      1.8M     $12.45        4.2h     312

  Total cost:      $12.45
  Total tokens:    2.5M (2.1M in + 380K out)
  Cache savings:   1.8M tokens read from cache
  Avg per session: 104K tokens, $0.52
  Total duration:  4.2h
```

### Group by tag, day, or model

```bash
# By tag
claude-token-report --by-tag

# By day
claude-token-report --by-day

# By model
claude-token-report --by-model

# Filter by date range
claude-token-report --since "2026-03-01" --until "2026-03-02"

# Filter by tag
claude-token-report --tag "batch-42"
```

### Export as CSV or JSON

```bash
claude-token-report --format csv > usage.csv
claude-token-report --format json --by-day > daily.json
```

## Usage in automation scripts

### Option 1: Drop-in replacement

Replace `claude` with `claude-token-log` in your scripts:

```bash
# Before
claude --model claude-opus-4-6 --output-format json -p "process this" > output.json

# After (logs tokens automatically)
claude-token-log --tag "batch" -- --model claude-opus-4-6 -p "process this" > output.txt
```

### Option 2: Sourceable library

For scripts that already handle Claude Code's JSON output:

```bash
#!/bin/bash
source token-logger.lib.sh

# Run claude with built-in logging
run_claude_with_logging --tag "my-job" --log ./usage.jsonl \
    -- --model claude-opus-4-6 --dangerously-skip-permissions -p "do something"

# Or log from an existing JSON output file
claude --output-format json -p "hello" > session.json
log_token_usage session.json --tag "manual" --log ./usage.jsonl

# Quick summary of recent usage
token_usage_summary --last 10
# → 10 sessions | 524,000 tokens (412,000 in + 112,000 out) | $4.2100
```

### Library functions

| Function | Description |
|---|---|
| `log_token_usage <file> [--tag TAG] [--log FILE]` | Extract and append token usage from a Claude JSON output file |
| `run_claude_with_logging [--tag TAG] [--log FILE] -- [claude args]` | Run claude and log tokens in one step |
| `token_usage_summary [--log FILE] [--last N]` | Print a one-line summary of usage |

## JSONL format

Each line in the log file is a JSON object:

```json
{
  "timestamp": "2026-03-02T19:45:00Z",
  "tag": "batch-42",
  "input_tokens": 85000,
  "output_tokens": 12000,
  "cache_creation": 5000,
  "cache_read": 72000,
  "cost_usd": 0.4200,
  "duration_ms": 45000,
  "num_turns": 8,
  "model": "claude-opus-4-6",
  "exit_code": 0
}
```

| Field | Description |
|---|---|
| `timestamp` | ISO 8601 UTC timestamp |
| `tag` | User-defined label for grouping/filtering |
| `input_tokens` | Total input tokens consumed |
| `output_tokens` | Total output tokens generated |
| `cache_creation` | Tokens written to prompt cache |
| `cache_read` | Tokens read from prompt cache (saves cost) |
| `cost_usd` | Total session cost in USD (from Claude Code) |
| `duration_ms` | Session duration in milliseconds |
| `num_turns` | Number of conversation turns |
| `model` | Model used (e.g., `claude-opus-4-6`) |
| `exit_code` | Claude Code exit code (0 = success) |

## Environment variables

| Variable | Description |
|---|---|
| `CLAUDE_TOKEN_LOG` | Default JSONL log path (default: `./token_usage.jsonl`) |

## Requirements

- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- `jq` (pre-installed on most systems, or `brew install jq`)
- `python3` (for report generation)

## License

MIT
