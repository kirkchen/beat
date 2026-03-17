#!/usr/bin/env python3
"""Analyze token usage from claude -p stream-json output."""

import json
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: analyze-token-usage.py <stream-json-file>")
        sys.exit(1)

    filepath = sys.argv[1]
    agents = {}
    main_usage = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0, "msgs": 0}

    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Main session usage
            if data.get("type") == "assistant" and "message" in data:
                msg = data["message"]
                if "usage" in msg:
                    u = msg["usage"]
                    main_usage["input"] += u.get("input_tokens", 0)
                    main_usage["output"] += u.get("output_tokens", 0)
                    main_usage["cache_create"] += u.get("cache_creation_input_tokens", 0)
                    main_usage["cache_read"] += u.get("cache_read_input_tokens", 0)
                    main_usage["msgs"] += 1

            # Subagent usage
            if data.get("type") == "user":
                for item in data.get("content", []):
                    if isinstance(item, dict) and "toolUseResult" in item:
                        result = item["toolUseResult"]
                        if isinstance(result, dict) and "agentId" in result:
                            aid = result["agentId"][:12]
                            usage = result.get("usage", {})
                            desc = result.get("prompt", "")[:50] if "prompt" in result else "subagent"
                            if aid not in agents:
                                agents[aid] = {"desc": desc, "input": 0, "output": 0, "msgs": 0}
                            agents[aid]["input"] += usage.get("input_tokens", 0)
                            agents[aid]["output"] += usage.get("output_tokens", 0)
                            agents[aid]["msgs"] += usage.get("tool_uses", 0)

    # Print report
    print(f"\n{'Agent':<15} {'Description':<40} {'Msgs':>5} {'Input':>10} {'Output':>10} {'Cost':>8}")
    print("-" * 90)

    total_input = main_usage["input"]
    total_output = main_usage["output"]

    cost = (main_usage["input"] * 3 + main_usage["output"] * 15) / 1_000_000
    print(f"{'main':<15} {'Main session':<40} {main_usage['msgs']:>5} {main_usage['input']:>10,} {main_usage['output']:>10,} ${cost:>6.2f}")

    for aid, info in sorted(agents.items()):
        c = (info["input"] * 3 + info["output"] * 15) / 1_000_000
        total_input += info["input"]
        total_output += info["output"]
        cost += c
        print(f"{aid:<15} {info['desc']:<40} {info['msgs']:>5} {info['input']:>10,} {info['output']:>10,} ${c:>6.2f}")

    print("-" * 90)
    total = total_input + total_output
    total_cost = (total_input * 3 + total_output * 15) / 1_000_000
    print(f"TOTALS: {total:,} tokens (input: {total_input:,}, output: {total_output:,}), estimated cost: ${total_cost:.2f}")

if __name__ == "__main__":
    main()
