#!/usr/bin/env bash

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.id')

total_in=$(echo "$input" | jq '.context_window.total_input_tokens')
total_out=$(echo "$input" | jq '.context_window.total_output_tokens')

# Pricing per 1M tokens
case "$model_id" in
  claude-opus-4*)
    price_in=15.00
    price_out=75.00
    ;;
  claude-sonnet-4*|claude-3-5-sonnet*)
    price_in=3.00
    price_out=15.00
    ;;
  claude-3-5-haiku*|claude-haiku-4*)
    price_in=0.80
    price_out=4.00
    ;;
  *)
    price_in=3.00
    price_out=15.00
    ;;
esac

usage=$(echo "$input" | jq '.context_window.current_usage')

if [ "$usage" != "null" ]; then
  current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  size=$(echo "$input" | jq '.context_window.context_window_size')
  pct=$((current * 100 / size))

  cost=$(awk "BEGIN {printf \"%.2f\", $total_in * $price_in / 1000000 + $total_out * $price_out / 1000000}")

  printf "%s | ctx %d%% | \$%s" "$model" "$pct" "$cost"
else
  printf "%s | ctx 0%% | \$0.00" "$model"
fi
