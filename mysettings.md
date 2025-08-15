# Установить и настроить Fail2ban для SSH

``` bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

# В секции [sshd]:

``` ini
enabled = true
port = ssh
maxretry = 5
findtime = 600
bantime = 3600
```

# Применить изменения:
``` bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

# Список пакетов

* aspnetcore-runtime-8.0
* certbot
* containerd.io
* curl
* docker-compose
* dotnet-sdk-8.0
* efibootmgr
* fail2ban
* git
* nginx
* p7zip-full
* postgresql-client-common
* rsync
* tree
* wakeonlan

# Автоматическое продление сертификатов Let's Encrypt

``` bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```