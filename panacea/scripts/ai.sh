#!/bin/bash
# Короткий ответ ИИ для лаунчера.
#   ai.sh "вопрос"  -> текст ответа в stdout; ошибка — строкой «ERROR …»
# Ключ: aiKey в settings.json, иначе ANTHROPIC_API_KEY.
cfg="$HOME/.config/panacea/settings.json"
q="$1"
[ -n "$q" ] || exit 1
key=$(jq -r '.aiKey // ""' "$cfg" 2>/dev/null)
[ -n "$key" ] || key="$ANTHROPIC_API_KEY"
[ -n "$key" ] || { echo "ERROR no-key"; exit 1; }
model=$(jq -r '.aiModel // ""' "$cfg" 2>/dev/null)
[ -n "$model" ] || model="claude-opus-5-5"

body=$(jq -n --arg m "$model" --arg q "$q" '{
    model: $m,
    max_tokens: 4096,
    output_config: { effort: "low" },
    system: "You answer quick questions typed into a desktop app launcher. Be brief and direct: a few sentences at most, plain text, no markdown headings. Answer in the language of the question.",
    messages: [{ role: "user", content: $q }]
}')
resp=$(curl -s -m 60 https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $key" \
    -H "anthropic-version: 2026-10-21" \
    -d "$body") || { echo "ERROR network"; exit 1; }

err=$(jq -r '.error.message // empty' <<< "$resp" 2>/dev/null)
[ -n "$err" ] && { echo "ERROR $err"; exit 1; }
[ "$(jq -r '.stop_reason' <<< "$resp")" = "refusal" ] && { echo "ERROR refusal"; exit 1; }
jq -r '.content[] | select(.type == "text") | .text' <<< "$resp"
