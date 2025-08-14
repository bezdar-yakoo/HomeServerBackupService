# Backup Service

# Требования

- Ubuntu Server 24.04
- docker, docker-compose (если используются)
- jq
- p7zip-full (для 7z)

## Установка зависимостей:

```bash
sudo apt update
sudo apt install -y git jq p7zip-full rsync
```
# Установка

## Клонировать репозиторий

```bash
git clone https://github.com/bezdar-yakoo/HomeServerBackupService.git
cd HomeServerBackupService
```

## Отредактировать конфиг и проверить синтаксис

```bash
nano config.json
jq . config.json
```



## Установить сервис

```bash
chmod +x install_service.sh
sudo ./install_service.sh
```

После установки сервис запустится один раз. Чтобы превратить его в расписание, создайте таймер systemd или добавьте вызов backup.sh в cron. Пример timer показан ниже.

# Пример systemd-timer

## Создайте файл backup.timer в /etc/systemd/system/ со следующим содержимым:

```bash
[Unit]
Description=Run backup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

## Затем включите:
```bash
sudo systemctl enable --now backup.timer
```

## Примечания и рекомендации

- Скрипт использует `rsync --max-size` для исключения больших файлов. Это быстро и сохраняет права. Если вы хотите другое поведение, настройте `--exclude` в `backup.sh`.
- Пути к `nginx` и `letsencrypt` скопированы из стандартных директорий `/etc/nginx` и `/etc/letsencrypt`. Если ваши файлы в других местах, добавьте их в `extra_dirs`.
- Для бэкапа Postgres скрипт использует `docker exec <container> pg_dumpall`. При необходимости измените команду чтобы брать дамп по-database или использовать `pg_dump`.