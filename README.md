# Домашнее задание №1: кластер HDFS

Для задания использовал Hadoop 3.4.3 и Docker Compose. Кластер состоит из пяти контейнеров:

- `namenode` — хранит метаданные и информацию о расположении блоков;
- `secondarynamenode` — периодически создаёт контрольные точки метаданных;
- `datanode1`, `datanode2`, `datanode3` — хранят блоки файлов.

Все контейнеры работают на одном компьютере и связаны общей сетью. В настройках указан коэффициент репликации 3, то есть каждый блок файла должен храниться на трёх DataNode.

Secondary NameNode не заменяет NameNode при отказе. Он объединяет `fsimage` и журнал изменений `edits`. Для этого задания YARN и MapReduce не нужны.

## Что нужно для запуска

Нужны Git, Bash и Docker с Compose версии 2.20 или выше. На macOS и Windows можно использовать Docker Desktop, на Windows команды выполнять в WSL2. Docker должен быть запущен.

Желательно выделить Docker 6 ГБ оперативной памяти и иметь около 8 ГБ свободного места. Порты 9870 и 9868 должны быть свободны. Java и Hadoop устанавливаются внутри образа, отдельно ставить их не нужно.

## Запуск

```bash
git clone https://github.com/slanalan1203/hdfs-homework-1.git
cd hdfs-homework-1
bash scripts/up.sh
```

При первом запуске скачивается Hadoop и собирается образ, поэтому нужно немного подождать. Скрипт создаёт сеть и тома для данных, форматирует новый NameNode, запускает все пять сервисов и проверяет кластер.

NameNode форматируется только при первом запуске. Если данные уже есть, они используются повторно.

При успешной проверке в конце будет строка:

```text
PASS: HDFS verification completed; reports saved in reports/
```

## Проверка кластера

Открыть [интерфейс NameNode](http://localhost:9870/dfshealth.html#tab-datanode). В нём должны быть:

- `Live Nodes: 3`;
- `Dead Nodes: 0`;
- три DataNode в состоянии `In Service`, без отказавших дисков.

В Overview не должно быть потерянных или повреждённых блоков. После завершения репликации не должно быть блоков с недостаточным числом реплик. Safe mode должен быть выключен.

Интерфейс Secondary NameNode: [http://localhost:9868](http://localhost:9868).

Повторно запустить автоматическую проверку можно так:

```bash
bash scripts/verify.sh
```

Она проверяет состояние контейнеров, наличие трёх работающих DataNode, запись и чтение тестового файла, три реальные реплики его блока и создание нового checkpoint у Secondary NameNode. Также проверяются доступные логи на записи `ERROR` и `FATAL`.

Результаты сохраняются в `reports/`. Если проверка не прошла, скрипт завершится с ошибкой.

Для проверки вручную:

```bash
# Состояние контейнеров
docker compose ps

# Отчёт HDFS о DataNode
docker compose exec -T --user hadoop namenode hdfs dfsadmin -report

# Проверка тестового файла и его реплик
docker compose exec -T --user hadoop namenode hdfs fsck /homework/hello.txt -files -blocks -locations

# Логи всех сервисов
docker compose logs --no-color
```

В выводе `fsck` должны быть `Status: HEALTHY` и `Live_repl=3`. Команды HDFS выполняются от пользователя `hadoop`, под которым работает NameNode.

## Остановка и повторный запуск

```bash
bash scripts/down.sh
bash scripts/up.sh
```

При остановке контейнеры удаляются, но данные остаются в пяти отдельных томах Docker.

Чтобы проверить, что файл сохраняется после пересоздания контейнеров:

```bash
bash tests/integration.sh
```

Этот тест запускает кластер, записывает файл, останавливает кластер, запускает его снова и сравнивает содержимое файла. При успехе выводится `PASS: file survived container recreation`.

Полностью удалить кластер вместе со всеми данными можно отдельной командой:

```bash
bash scripts/reset.sh --delete-all-data
```

После неё следующий запуск создаст пустой кластер. Не нужно форматировать только NameNode, оставляя старые данные DataNode: их Cluster ID перестанут совпадать.

## Основные файлы

- `Dockerfile` — образ с Java 11 и Hadoop. Архив Hadoop проверяется по SHA-512.
- `compose.yaml` — пять сервисов, сеть, тома и проверки состояния.
- `config/core-site.xml` — адрес NameNode.
- `config/hdfs-site.xml` — пути хранения, репликация и настройки checkpoint.
- `docker/entrypoint.sh` — первоначальное форматирование и запуск нужного сервиса.
- `scripts/` — скрипты запуска, проверки и остановки.
- `tests/` — тесты проверки состояния узлов и сохранности данных.
- `.github/workflows/hdfs.yml` — запуск тестов через GitHub Actions.

Статус выполненных проверок указан в [VALIDATION.md](VALIDATION.md). Во вкладке Actions можно посмотреть результат автоматического запуска и скачать отчёты.

## Если запуск не получился

Сначала проверить `docker info` и `docker compose logs --tail 100`. Если Docker на паузе, нажать Resume. Если контейнеры завершаются из-за нехватки памяти, увеличить память Docker. Если занят порт 9870 или 9868, освободить его либо изменить внешний порт в `compose.yaml`.

Стенд предназначен для локальной работы: веб-интерфейсы доступны только с этого компьютера, а HDFS-команды выполняются внутри контейнеров. Ссылки на внутренние адреса DataNode из интерфейса могут не открываться в браузере компьютера.

## Документация

При настройке использовал документацию Apache:

- [Настройка кластера Hadoop](https://hadoop.apache.org/docs/r3.4.3/hadoop-project-dist/hadoop-common/ClusterSetup.html)
- [HDFS Users Guide](https://hadoop.apache.org/docs/r3.4.3/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [Команды HDFS](https://hadoop.apache.org/docs/r3.4.3/hadoop-project-dist/hadoop-hdfs/HDFSCommands.html)
