#!/usr/bin/env bash
# Проверка публичного репозитория: нет секретов, IP, запрещенных слов и запрещенных файлов.
# Запускается в CI и локально перед коммитом.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
GREP_OPTS=(-rInE --exclude-dir=.git --exclude=check_public_safe.sh)

report() { echo "::error::$1"; echo "$2"; fail=1; }

# 1. Запрещенные термины (кроме HTTP-заголовка User-Agent)
out=$(grep "${GREP_OPTS[@]}" -i '\bagents?\b|агент' . | grep -viE 'user-agent' || true)
[ -n "$out" ] && report "Запрещенные термины (agent/агент)" "$out"

# 2. Приватные IP-адреса
out=$(grep "${GREP_OPTS[@]}" '\b(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}(\.[0-9]{1,3})?\b' . || true)
[ -n "$out" ] && report "Найдены приватные IP-адреса" "$out"

# 3. Блоки приватных ключей
out=$(grep "${GREP_OPTS[@]}" -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' . || true)
[ -n "$out" ] && report "Найден приватный ключ" "$out"

# 4. Запрещенные файлы (разрешен только .env.example)
out=$(find . -path ./.git -prune -o -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.crt' -o -name '*.pfx' -o -name '*.p12' -o -name '*.priv' \) -print | grep -v '\.env\.example$' || true)
[ -n "$out" ] && report "Найдены запрещенные файлы" "$out"

# 5. Обязательные файлы
for f in .gitignore .dockerignore .env.example; do
  [ -f "$f" ] || report "Отсутствует обязательный файл" "$f"
done

if [ "$fail" -ne 0 ]; then
  echo "Проверка публичной безопасности НЕ пройдена"; exit 1
fi
echo "Проверка публичной безопасности пройдена"
