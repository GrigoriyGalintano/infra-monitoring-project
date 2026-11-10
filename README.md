# infra-monitoring-project

Учебный проект для проверки доступности API, анализа access.log и запуска echo-сервиса за Nginx.

IP-адреса в примерах и тестовых логах вымышлены. Публикуемый дамп обезличен: реальные адреса, MAC и метаданные компьютера заменены или удалены.

## Состав проекта

- `check_api.sh`: HTTP-проверка с ожидаемым кодом 200.
- `analyze_logs.sh`: генерация 360 записей и статистика по IPv4 и HTTP-кодам.
- `docker-compose.yml`: контейнеры `api` и `proxy` в отдельной внутренней сети.
- `nginx/default.conf`: проксирование порта 80 на `api:8080`.
- `.github/workflows/ci.yml`: проверки Bash, логов и Docker при открытии PR в `main`.
- `reports/traffic-report.md`: результаты захвата и анализа сетевого трафика.

## Требования

Для локальной работы нужны Bash, curl, grep, awk, sort, uniq, Docker Engine и Docker Compose v2. На Windows скрипты можно запускать в Git Bash, а контейнеры через Docker Desktop в режиме Linux containers. Для захвата трафика используются Wireshark и доступный драйвер захвата.

## Запуск

```bash
chmod +x check_api.sh analyze_logs.sh
docker compose up -d
curl http://localhost:80
./check_api.sh http://localhost:80
./analyze_logs.sh
```

Ожидаемый ответ прокси: `Monitoring Service Active`. API слушает порт 8080 внутри Docker-сети. На хост опубликован порт 80 сервиса `proxy`.

Если установлен отдельный Compose v1, эквивалентная команда запуска: `docker-compose up -d`.

```bash
docker compose ps
docker compose logs --tail=50
docker compose down
```

## Проверка API

```bash
./check_api.sh https://httpbin.org/status/200
echo $?
./check_api.sh https://httpbin.org/status/404
echo $?
```

При HTTP 200 скрипт печатает `API доступен` и завершает работу с кодом 0. Другой HTTP-код или ошибка соединения дают код 1. При сетевой ошибке код ответа обычно равен `000`. Перенаправления не считаются успешной проверкой. Таймаут соединения составляет 5 секунд, всего запроса 15 секунд. Запуск без URL или с неподдерживаемой схемой также возвращает 1.

## Анализ логов

```bash
./analyze_logs.sh
./analyze_logs.sh /var/log/nginx/access.log
```

Если файла нет, скрипт создаёт 360 тестовых записей. Существующий файл не перезаписывается. Парсер принимает записи с корректным IPv4, HTTP-запросом и трёхзначным кодом ответа. Пустые и некорректные строки пропускаются.

Для нового тестового файла результат такой:

```text
Общее количество запросов: 360
Топ-3 IP-адреса:
  192.0.2.10: 180
  198.51.100.5: 108
  203.0.113.8: 54
Запросов с кодами 4xx: 90
Запросов с кодами 5xx: 60
```

## CI и работа с ветками

Рабочая ветка: `feature/monitoring`. Pull Request направляется в `main`. Задача `Bash and Docker checks` проверяет синтаксис обоих скриптов, HTTP 200 от httpbin, статистику тестовых логов и ответ Nginx после запуска Docker Compose. В конце контейнеры удаляются.

```bash
bash -n check_api.sh
bash -n analyze_logs.sh
```

Для `main` предусмотрена защита: изменения через PR, успешная проверка `Bash and Docker checks`, запрет принудительной отправки и удаления ветки. Реальное состояние защиты и CI следует проверять в настройках репозитория и на странице PR.

## Захват трафика

Результаты и инструкции находятся в [отчёте](reports/traffic-report.md). Дамп содержит только три тестовых HTTP-соединения к httpbin. Методы и коды ответов сохранены. Адреса в IP-заголовках и поле `origin` заменены учебными значениями, MAC заменены, метаданные интерфейса и компьютера удалены. Временные отметки приведены к условной шкале с сохранением интервалов. В дампе нет ключей TLS, авторизованных запросов и постороннего трафика.

## SSH и безопасная передача файлов

Примеры рассчитаны на Linux-сервер с установленными Docker Engine и Compose. Замените `deploy@example.com` на свой адрес. Перед первым подключением сверьте отпечаток SSH-ключа сервера с администратором по доверенному каналу. Не отключайте проверку ключа хоста.

Создайте отдельный ключ с парольной фразой и добавьте его в агент:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/infra_monitoring -C "infra-monitoring-deploy"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/infra_monitoring
ssh-copy-id -i ~/.ssh/infra_monitoring.pub deploy@example.com
ssh -i ~/.ssh/infra_monitoring deploy@example.com
```

Приватный ключ остаётся на рабочей машине. На сервер копируется только файл `.pub`. В OpenSSH для Windows вместо `ssh-copy-id` можно передать публичный ключ так:

```powershell
Get-Content "$env:USERPROFILE\.ssh\infra_monitoring.pub" | ssh deploy@example.com 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

Вариант передачи через SCP из корня проекта:

```bash
tar -czf /tmp/infra-monitoring-project.tar.gz \
  README.md .gitignore .gitattributes check_api.sh analyze_logs.sh \
  docker-compose.yml nginx .github reports
ssh -i ~/.ssh/infra_monitoring deploy@example.com 'mkdir -p ~/apps/infra-monitoring-project'
scp -i ~/.ssh/infra_monitoring /tmp/infra-monitoring-project.tar.gz deploy@example.com:~/apps/
ssh -i ~/.ssh/infra_monitoring deploy@example.com \
  'tar -xzf ~/apps/infra-monitoring-project.tar.gz -C ~/apps/infra-monitoring-project && cd ~/apps/infra-monitoring-project && chmod +x check_api.sh analyze_logs.sh && docker compose up -d && ./check_api.sh http://localhost:80'
```

Вариант без промежуточного архива:

```bash
tar -czf - README.md .gitignore .gitattributes check_api.sh analyze_logs.sh \
  docker-compose.yml nginx .github reports | \
  ssh -i ~/.ssh/infra_monitoring deploy@example.com \
  'mkdir -p ~/apps/infra-monitoring-project && tar -xzf - -C ~/apps/infra-monitoring-project && cd ~/apps/infra-monitoring-project && chmod +x check_api.sh analyze_logs.sh && docker compose up -d && ./check_api.sh http://localhost:80'
```

Команды передают только перечисленные файлы проекта. Локальные логи, `.git`, временные файлы и ключи в архив не включаются. Пользователю `deploy` нужен доступ к Docker; учётная запись с доступом к Docker фактически имеет расширенные права на сервере. Для публичного сервиса добавьте TLS перед Nginx и настройте правила доступа под конкретное окружение.

## Источники

- [Параметры hashicorp/http-echo](https://github.com/hashicorp/http-echo)
- [Сети Docker Compose](https://docs.docker.com/compose/how-tos/networking/)
- [Сервисы Docker Compose](https://docs.docker.com/reference/compose-file/services/)
- [GitHub Actions Checkout](https://github.com/actions/checkout)
