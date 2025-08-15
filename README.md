# Backup Service

# Требования

* Ubuntu Server 24.04
* docker, docker-compose (если используются)
* jq
* p7zip-full (для 7z)

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

После установки сервис запустится один раз. Для автоматического запуска используйте systemd-timer. Скрипт `install_service.sh` может сгенерировать таймер из поля `timer.on_calendar` в `config.json`. Поле хранит расписание и выглядит так:

```json
"timer": {
  "on_calendar": "daily"
}
```

Допустимые значения: короткие алиасы `hourly`, `daily`, `weekly`, `monthly` или любая валидная строка `OnCalendar`, например `*-*-* 03:00:00` или `Mon *-*-* 04:30:00`.

# Таймер systemd (рекомендуется)

Systemd-timer запускает `backup.service` по расписанию. Включите таймер через `install_service.sh` или создайте файл вручную.

## Пример содержимого `/etc/systemd/system/backup.timer` (генерируется автоматически):

```ini
[Unit]
Description=Run backup.service on schedule

[Timer]
OnCalendar=daily
Persistent=true
Unit=backup.service

[Install]
WantedBy=timers.target
```

`Persistent=true` гарантирует запуск пропущенных заданий при загрузке системы.

## Команды управления таймером

```bash
# Включить/запустить таймер
sudo systemctl enable --now backup.timer

# Отключить таймер
sudo systemctl disable --now backup.timer

# Статус таймера
sudo systemctl status backup.timer

# Список таймеров и следующая активация
sudo systemctl list-timers --all | grep backup

# Принудительно запустить бэкап
sudo systemctl start backup.service

# Логи сервиса
sudo journalctl -u backup.service -f
```

# Управление через `manager`

В репозитории есть скрипт `manager` с пунктами для управления сервисом и таймером. Полезные опции:

* **6) Show timer status** — показывает статус таймера и ближайшие срабатывания
* **7) Edit timer schedule** — редактирует `config.json` `timer.on_calendar`
* **8) Enable timer** — `systemctl enable --now backup.timer`
* **9) Disable timer** — `systemctl disable --now backup.timer`
* **10) Start timer now** — `systemctl start backup.timer`
* **11) Stop timer** — `systemctl stop backup.timer`
* **12) Reload timer units** — `systemctl daemon-reload` и перезапуск таймера
* **13) Apply timer from config** — заново создает таймер из `config.json` (вызов `install_service.sh`)

Если вы изменили `config.json.timer.on_calendar` вручную, примените изменения через пункт **13** в `manager` или выполните `sudo bash install_service.sh`.

# Примечания и рекомендации

* Скрипт использует `rsync --max-size` для исключения больших файлов. Если нужно другое поведение, настройте `--exclude` или `--max-size` в `backup.sh`.
* Пути к `nginx` и `letsencrypt` копируются из `/etc/nginx` и `/etc/letsencrypt`. При нестандартных путях добавьте их в `extra_dirs`.
* Для бэкапа Postgres используется `docker exec <container> pg_dumpall`. При необходимости измените команду.
* При изменении таймера вручную не забудьте выполнить `sudo systemctl daemon-reload`.

# Примеры OnCalendar

* `daily` — каждый день в 00:00
* `hourly` — каждый час
* `weekly` — каждую неделю
* `*-*-* 03:00:00` — каждый день в 03:00
* `Mon *-*-* 04:30:00` — каждый понедельник в 04:30

# Быстрый чек-лист после установки

1. Отредактировать `config.json`, задать `output_dir`, `tmp_base`, `timer.on_calendar`.
2. `chmod +x install_service.sh` и `sudo ./install_service.sh`.
3. Проверить таймер: `systemctl status backup.timer` и `systemctl list-timers --all | grep backup`.
4. При изменении расписания применить через `manager` пункт 13 или `sudo bash install_service.sh`.
