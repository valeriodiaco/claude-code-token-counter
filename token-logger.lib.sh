#!/bin/bash
# token-logger.lib.sh — Sourceable library for token usage logging
#
# Source this in your automation scripts to add token tracking
# to any `claude --output-format json` session.
#
# Usage:
#   source /path/to/token-logger.lib.sh
#
#   # After running claude --output-format json > output.json:
#   log_token_usage output.json --tag "my-job" --log ./usage.jsonl
#
#   # Or use the run-and-log wrapper:
#   run_claude_with_logging --tag "my-job" --log ./usage.jsonl -- --model claude-opus-4-6 -p "hello"

TOKEN_LOGGER_VERSION="1.0.0"

# Log token usage from a Claude Code JSON output file
# Usage: log_token_usage <json_file> [--tag TAG] [--log JSONL_FILE] [--duration SECONDS]
log_token_usage() {
    local json_file="$1"
    shift

    local tag=""
    local log_file="${CLAUDE_TOKEN_LOG:-./token_usage.jsonl}"
    local duration=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag) tag="$2"; shift 2 ;;
            --log) log_file="$2"; shift 2 ;;
            --duration) duration="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -f "$json_file" ]]; then
        return 1
    fi

    if ! jq -e '.' "$json_file" > /dev/null 2>&1; then
        return 1
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq -c --arg ts "$timestamp" \
          --arg tag "$tag" \
          --arg dur "${duration:-0}" \
        '{
            timestamp: $ts,
            tag: $tag,
            input_tokens: (.usage.input_tokens // 0),
            output_tokens: (.usage.output_tokens // 0),
            cache_creation: (.usage.cache_creation_input_tokens // 0),
            cache_read: (.usage.cache_read_input_tokens // 0),
            cost_usd: (.total_cost_usd // 0),
            duration_ms: (.duration_ms // ($dur | tonumber * 1000)),
            num_turns: (.num_turns // 0),
            model: (.model // "unknown"),
            exit_code: 0
        }' "$json_file" >> "$log_file" 2>/dev/null
}

# Run claude and log token usage in one step
# Usage: run_claude_with_logging [--tag TAG] [--log JSONL_FILE] [-- claude-args...]
run_claude_with_logging() {
    local tag=""
    local log_file="${CLAUDE_TOKEN_LOG:-./token_usage.jsonl}"
    local claude_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag) tag="$2"; shift 2 ;;
            --log) log_file="$2"; shift 2 ;;
            --) shift; claude_args=("$@"); break ;;
            *) claude_args+=("$1"); shift ;;
        esac
    done

    # Add --output-format json if not present
    local has_format=false
    for arg in "${claude_args[@]}"; do
        [[ "$arg" == "--output-format" ]] && has_format=true
    done
    if ! $has_format; then
        claude_args=("--output-format" "json" "${claude_args[@]}")
    fi

    local json_file
    json_file=$(mktemp "${TMPDIR:-/tmp}/claude-token-XXXXXX.json")

    local start_time
    start_time=$(date +%s)
    local exit_code=0

    claude "${claude_args[@]}" > "$json_file" 2>&1 || exit_code=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Print result to stdout
    if jq -e '.result' "$json_file" > /dev/null 2>&1; then
        jq -r '.result // empty' "$json_file"
    fi

    # Log token usage
    log_token_usage "$json_file" --tag "$tag" --log "$log_file" --duration "$duration"
    local log_ok=$?

    rm -f "$json_file"

    if [[ $log_ok -eq 0 ]]; then
        return $exit_code
    else
        return $exit_code
    fi
}

# Get a quick summary line from the last N records
# Usage: token_usage_summary [--log JSONL_FILE] [--last N]
token_usage_summary() {
    local log_file="${CLAUDE_TOKEN_LOG:-./token_usage.jsonl}"
    local last_n=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --log) log_file="$2"; shift 2 ;;
            --last) last_n="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -f "$log_file" ]]; then
        echo "No usage data"
        return 1
    fi

    local data
    if [[ "$last_n" -gt 0 ]]; then
        data=$(tail -n "$last_n" "$log_file")
    else
        data=$(cat "$log_file")
    fi

    echo "$data" | python3 -c "
import json, sys

records = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        records.append(json.loads(line))
    except:
        continue

if not records:
    print('No records')
    sys.exit()

total_in = sum(r.get('input_tokens', 0) for r in records)
total_out = sum(r.get('output_tokens', 0) for r in records)
total_cost = sum(r.get('cost_usd', 0) for r in records)
sessions = len(records)

print(f'{sessions} sessions | {total_in + total_out:,} tokens ({total_in:,} in + {total_out:,} out) | \${total_cost:.4f}')
" 2>/dev/null
}
