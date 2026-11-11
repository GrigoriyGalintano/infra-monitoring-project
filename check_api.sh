#!/usr/bin/env bash
set -uo pipefail

if [[ $# -ne 1 || ! $1 =~ ^https?://[^/[:space:]]+ ]]; then
    printf 'Использование: %s URL_HTTP_ИЛИ_HTTPS\n' "$0" >&2
    exit 1
fi

if ! status=$(curl --silent --show-error --output /dev/null \
    --connect-timeout 5 --max-time 15 --write-out '%{http_code}' \
    --proto '=http,https' -- "$1"); then
    printf 'API недоступен, код ответа: %s\n' "${status:-000}"
    exit 1
fi

if [[ $status == 200 ]]; then
    printf 'API доступен\n'
    exit 0
fi

printf 'API недоступен, код ответа: %s\n' "$status"
exit 1
