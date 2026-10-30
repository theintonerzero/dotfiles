#!/usr/bin/env bash
# claude code's status line, in pills like the prompt's: the model and its effort, the context window
# as a bar with how much of it is used, and the session's cost; 16 colours only, so the terminal's
# theme picks them. a part whose fields are missing is left out, and it always exits 0, as claude code
# blanks the line otherwise
export LC_ALL=C

# the pills' rounded caps, U+E0B6 and U+E0B4, as utf-8
left=$'\xee\x82\xb6' right=$'\xee\x82\xb4'

# sgr <codes>: a colour escape, or nothing with NO_COLOR
sgr() { [[ -n ${NO_COLOR:-} ]] || printf '\033[%sm' "$1"; }

# pill <cap colour> <text colours> <text>: the text between rounded caps; the text alone with NO_COLOR
pill() {
  if [[ -n ${NO_COLOR:-} ]]; then
    printf '%s' "$3"
  else
    printf '\033[0;%sm%s\033[%sm%s\033[0;%sm%s\033[0m' "$1" "$left" "$2" "$3" "$1" "$right"
  fi
}

# tokens <n>: n tokens, in thousands (84k), and in millions from a million on (1M, 1.5M)
tokens() {
  local n=$1 m
  if ((n < 1000)); then
    printf '%d' "$n"
  elif ((n < 999500)); then
    printf '%dk' $(((n + 500) / 1000))
  else
    m=$(((n + 50000) / 100000))
    if ((m % 10 == 0)); then printf '%dM' $((m / 10)); else printf '%d.%dM' $((m / 10)) $((m % 10)); fi
  fi
}

# the fields, apart by the unit separator, each empty when missing or of the wrong type; the context's
# tokens are the ones used_percentage counts: input, cache creation and cache reads
model='' effort='' pct='' used='' size='' spent=''
IFS=$'\x1f' read -r model effort pct used size spent < <(jq -r 'objects | [
  ((.model | objects | .display_name | strings) // ""),
  ((.effort | objects | .level | strings) // ""),
  ((.context_window | objects | .used_percentage | numbers) // ""),
  ((.context_window | objects | .current_usage | objects
    | [.input_tokens, .cache_creation_input_tokens, .cache_read_input_tokens]
    | map(numbers) | add) // ""),
  ((.context_window | objects | .context_window_size | numbers) // ""),
  ((.cost | objects | .total_cost_usd | numbers) // "")
] | map(tostring | gsub("[[:cntrl:]]"; "")) | join("\u001f")' 2>/dev/null)

first=${model:-Claude}
if [[ -n $effort ]]; then first+=" · $effort"; fi
line=$(pill 90 '30;100' "$first")

number='^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$'
if [[ $used =~ ^[0-9]+$ && $size =~ ^[0-9]+$ ]] && ((size > 0)); then
  if [[ $pct =~ $number ]]; then pct=$(printf '%.0f' "$pct"); else pct=$((used * 100 / size)); fi
  cells=$(((pct + 5) / 10))
  if ((cells > 10)); then cells=10; fi
  full=$(printf '%*s' "$cells" '')
  rest=$(printf '%*s' $((10 - cells)) '')
  body="${full// /━}$(sgr 90)${rest// /─}$(sgr 97) $pct% · $(tokens "$used")/$(tokens "$size")"
  line+=" $(pill 30 '97;40' "$body")"
fi
if [[ $spent =~ $number ]]; then
  line+=" $(pill 30 '97;40' "$(printf '$%.2f' "$spent")")"
fi
printf '%s\n' "$line"
exit 0
