# Анализ сетевого трафика

## Дамп

[traffic.pcapng](traffic.pcapng) содержит три HTTP-соединения к публичному API httpbin. Запросы отправлены через curl, захват выполнен Wireshark Dumpcap. В файле 30 Ethernet-пакетов, размер 4200 байт. Интервал между первым и последним пакетом составляет около 1,81 секунды.

SHA256:

```text
68603d5f5f4f02340601b3bef9000797bf444f728b986c50b771eca1f5adf91d
```

## IP-адреса

| Адрес в дампе | Роль |
| --- | --- |
| `192.0.2.10` | HTTP-клиент |
| `198.51.100.20` | HTTP-сервер |

## Методы и коды ответов

| Метод | URL | Ответ | Кадры запроса и ответа |
| --- | --- | --- | --- |
| GET | `http://httpbin.org/get` | `200 OK` | 4 и 6 |
| POST | `http://httpbin.org/status/201` | `201 Created` | 11 и 14 |
| GET | `http://httpbin.org/status/404` | `404 Not Found` | 19 и 22 |

Использованы GET и POST. Код 200 означает успешный ответ, 201 обозначает создание ресурса, 404 обозначает отсутствие ресурса. Эндпоинты `/status/201` и `/status/404` намеренно возвращают выбранный код; создание ресурса в этом опыте не выполнялось.

## Фильтрация

Откройте дамп в Wireshark и примените фильтры отображения:

```text
http
http.request
http.response
http.request.method == "POST"
http.response.code >= 400
ip.addr == 192.0.2.10
```

Фильтр `http` показывает шесть пакетов с HTTP-запросами и ответами. Остальные пакеты обеспечивают работу TCP. Для захвата, содержащего HTTPS, применим фильтр `http || tls`, однако без ключей сеанса он не раскрывает зашифрованные методы и статусы.

Проверка сохранённого файла через TShark:

```bash
tshark -n -r reports/traffic.pcapng \
  -Y 'http.request or http.response' \
  -T fields -E header=y \
  -e frame.number -e ip.src -e ip.dst \
  -e http.request.method -e http.request.uri -e http.response.code
```

## Повторение опыта

Сначала определите активный интерфейс и текущий IPv4 сервера. Подставьте их в фильтр захвата.

```bash
dumpcap -D
nslookup httpbin.org
```

Запустите захват на выбранном интерфейсе с ограничением на адрес API и TCP-порт 80. Во втором терминале выполните:

```bash
curl -X GET http://httpbin.org/get
curl -X POST http://httpbin.org/status/201
curl -X GET http://httpbin.org/status/404
```

В PowerShell используйте `curl.exe`.

## Источники

- [Фильтрация пакетов в Wireshark](https://www.wireshark.org/docs/wsug_html_chunked/ChapterWork.html)
