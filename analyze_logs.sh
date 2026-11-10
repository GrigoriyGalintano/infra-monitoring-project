#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ${1:-access.log} == -* ]]; then
    printf 'Использование: %s [файл_лога]\n' "$0" >&2
    exit 1
fi

log_file=${1:-access.log}

if [[ ! -e $log_file ]]; then
    awk 'BEGIN {
        split("192.0.2.10 198.51.100.5 203.0.113.8 192.0.2.20", ips, " ")
        split("GET POST PUT", methods, " ")
        split("/api/users /api/login /api/health", paths, " ")
        for (i = 0; i < 360; i++) {
            slot = i % 20
            ip = ips[slot < 10 ? 1 : slot < 16 ? 2 : slot < 19 ? 3 : 4]
            status_slot = i % 12
            status = status_slot < 2 ? 404 : status_slot == 2 ? 401 : status_slot == 3 ? 500 : status_slot == 4 ? 503 : 200
            printf "%s - - [15/Aug/2026:10:%02d:%02d] \"%s %s HTTP/1.1\" %d\n", \
                ip, int(i / 60), i % 60, methods[i % 3 + 1], paths[i % 3 + 1], status
        }
    }' > "$log_file"
    printf 'Создан тестовый лог: %s (360 строк)\n' "$log_file"
fi

if [[ ! -f $log_file || ! -r $log_file ]]; then
    printf 'Не удалось прочитать файл: %s\n' "$log_file" >&2
    exit 1
fi

octet='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
ipv4="${octet}(\.${octet}){3}"
pattern="^${ipv4} - - \[[^]]+\] \"[^\"[:space:]]+ [^\"[:space:]]+ HTTP/[0-9.]+\" [1-5][0-9]{2}([[:space:]]|$)"

if records=$(grep -E -- "$pattern" "$log_file"); then
    :
else
    grep_status=$?
    if [[ $grep_status -ne 1 ]]; then
        exit 1
    fi
fi

printf '%s\n' "$records" | awk 'NF { total++ } END { printf "Общее количество запросов: %d\n", total }'
printf 'Топ-3 IP-адреса:\n'
printf '%s\n' "$records" | awk 'NF { print $1 }' | sort | uniq -c | sort -k1,1nr -k2,2 | awk 'NR <= 3 { printf "  %s: %d\n", $2, $1 }'
printf '%s\n' "$records" | awk -F '"' '
    $3 ~ /^[[:space:]]+4[0-9][0-9]([[:space:]]|$)/ { client_errors++ }
    $3 ~ /^[[:space:]]+5[0-9][0-9]([[:space:]]|$)/ { server_errors++ }
    END {
        printf "Запросов с кодами 4xx: %d\n", client_errors
        printf "Запросов с кодами 5xx: %d\n", server_errors
    }
'
