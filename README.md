# Настройка обновления устройств Ubiquiti / Unifi при проблемах доступа к серверам обновлений

## Описание

Описание процесса настройки обновления для устройств **Ubiquiti/Unifi**, для тех, у кого есть проблемы доступа к серверам обновлений **Ubiquiti**, размещённых на **Amazon**.

Суть всех настроек сводится к достижению одной цели — все обновления устанавливаются по нажатию кнопки **Update** либо **Install**.

---

## Варианты настройки

Настроить возможность получения обновлений можно двумя способами:

1. Для обновления **собственной сети**  
2. Для обновления **нескольких сетей**

Также для настройки нужна **рабочая VPS**, находящаяся **вне подсанкционного геоблока**, до которой поднят и работает туннель.

---

## Вариант 1 — Без VPS, с туннелем

Данный вариант подойдёт тем, у кого **нет своего VPS**, но есть возможность организации туннеля.

В собственной сети необходимо развернуть **виртуальную машину (Linux)**.

### Настройка виртуальной машины

Обновляем список доступных пакетов:

```bash
sudo apt update
```

Меняем DNS сервер:

```bash
sudo echo "nameserver 9.9.9.9" > /etc/resolv.conf
```

### Установка Nginx

Устанавливаем **nginx** (либо **haproxy**, **traefik**, но пример приведён на nginx и Debian):

```bash
sudo apt install nginx -y
```

Проверяем наличие модуля **ngx_stream_module**:

```bash
sudo nginx -V 2>&1 | grep --color stream
```

Если в выводе есть что-то вроде:

```
--with-stream=dynamic
```

или

```
--with-stream
```

значит поддержка stream есть.

Если модуль **динамический** (`--with-stream=dynamic`), его нужно явно загрузить в конфиге:

```bash
sudo nano /etc/nginx/nginx.conf
```

Добавляем (в самом начале, до блока `events`):

```nginx
load_module modules/ngx_stream_module.so;
```

Сохраняем файл и перезапускаем Nginx:

```bash
sudo systemctl restart nginx
```

### Подготовка конфигурации stream

Создаём каталог для конфигов stream:

```bash
sudo mkdir /etc/nginx/stream.d || true
```

Редактируем `nginx.conf` и добавляем в самом конце:

```bash
sudo nano /etc/nginx/nginx.conf
```

Добавляем строку:

```nginx
include /etc/nginx/stream.d/*.conf;
```

---

## Выбор конфигурационного файла

Выберите один из конфигурационных файлов в зависимости от необходимости:

1. `conf/stream-ubnt.conf` — стрим **только fw-download.ubnt.com** и **fw-download.ui.com**  
2. `conf/stream-ubnt-only-dl.conf` — стрим как в пункте 1 + **beta**, **early access**, **release candidate**  
3. `conf/stream-all.conf` — стрим всего, включая **fw-update.ubnt.com** и **fw-update.ui.com**

Пример приведён на основе **первого варианта** — `conf/stream-ubnt.conf`.

Копируем выбранный файл конфигурации в каталог stream:

```bash
sudo cp conf/stream-ubnt.conf /etc/nginx/stream.d/
```

Перезапускаем Nginx:

```bash
sudo systemctl restart nginx
```

---

## Настройка туннеля

Теперь нужно завернуть трафик с созданной виртуальной машины в туннель.

### Настройка Policy Table

В **Network Application** переходим:  
**Settings → Policy Table → Create Net Policy**

В боковой панели выбираем:

- **Type**: `Route`  
- **Name**: любое осмысленное имя  
- **Type**: `Policy-Based`  
- **Interface/VPN Tunnel**: имя туннеля до VPS  
- **Source**: `Device/Network` → выбираем виртуальную машину (по IP или другому параметру)  
- **Destination**: `Any`

Нажимаем **Add** — готово.

---

## Настройка DNS

В **Network Application** нажимаем:  
**Create Net Policy → DNS**

Оставляем:

- **Type** = `Host (A)`  
- **Domain Name** = `fw-download.ubnt.com`  
- **IP Address** = локальный IP виртуальной машины

Жмём **Add** — готово.

Повторяем то же для домена `fw-download.ui.com`.

Если используются другие конфигурационные файлы nginx (`stream-ubnt-all.conf` или `stream-ubnt-only-dl.conf`), аналогичные действия выполняются для всех доменов, указанных в конфиге.

---

## Полный список доменов по конфигурационным файлам

### `conf/stream-ubnt.conf`
- fw-download.ubnt.com  
- fw-download.ui.com  

### `conf/stream-ubnt-only-dl.conf`
- fw-download.ubnt.com  
- fw-download.ui.com  
- apt.artifacts.ui.com  
- apt-release-candidate.artifacts.ui.com  
- apt-beta.artifacts.ui.com  

### `conf/stream-all.conf`
- fw-download.ubnt.com  
- fw-download.ui.com  
- fw-update.ubnt.com  
- fw-update.ui.com  
- apt.artifacts.ui.com  
- apt-release-candidate.artifacts.ui.com  
- apt-beta.artifacts.ui.com  

> ⚠️ **Примечание:**  
> Заворачивать домены `fw-update.ubnt.com` и `fw-update.ui.com` в стрим **не имеет смысла** — эти домены не заблокированы, и **Network Application** получает сведения напрямую.

---

## Проверка работы

Настройка **варианта 1** завершена.  
Для проверки идём:  
**Settings → Control Plane → Updates**  
Пробуем обновиться либо установить необходимые пакеты.

---

## Вариант 2 — С VPS

Данный вариант подразумевает, что у вас **уже есть VPS**, и к ней есть доступ по **SSH**.

Подключаемся к VPS. Если nginx не установлен — ставим, как описано в **варианте 1**.

Допустим, у вас поднят туннель и имеются следующие адреса:

- Ваш IP в туннеле: `10.1.1.2`  
- IP сервера в туннеле: `10.1.1.1`

Как и в первом варианте:

- Выбираем нужный **конфигурационный файл стрима nginx**  
- Добавляем **доменные имена в Policy Table** (аналогично варианту 1), только в поле **IP Address** указываем IP **сервера** в туннеле.

---

## Добавление статического маршрута (если требуется)

Иногда может потребоваться добавить **static route** для обратной стороны туннеля.

В **Network Application** переходим:  
**Settings → Policy Table → Create Net Policy**

В боковой панели выбираем:

- **Type**: `Route`  
- **Name**: любое осмысленное  
- **Type**: `Static`  
- **Interface/VPN Tunnel**: имя туннеля до VPS  
- **Device**: `Gateway`  
- **Distance**: `1`  
- **Interface**: выбираем имя туннеля

Жмём **Add** — готово.

---

## Проверка

Настройка **варианта 2** завершена.  
Для проверки идём в **Settings → Control Plane → Updates** и пробуем обновиться или установить необходимые пакеты.
