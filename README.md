# iSponsorBlockTV

iOS приложение для блокировки спонсорских сегментов на YouTube через удаленный сервер.

## 🚀 Два варианта использования

1. **📱 Полноценный iOS клиент** - [`README_iOS_CLIENT.md`](README_iOS_CLIENT.md)
   - Прямое подключение к YouTube TV (как в оригинальном iSponsorBlockTV)
   - Ввод кода связывания с телевизора  
   - Автоматический пропуск спонсоров в реальном времени
   - **Рекомендуется для реального использования**

2. **🧪 Демо-интерфейс** - (этот файл)
   - Тестовый сервер с демо-данными
   - Для ознакомления с интерфейсом
   - Не подключается к реальным устройствам

## Возможности

- 🚫 Блокировка спонсорских сегментов
- 📺 Поддержка нескольких устройств (Apple TV, Smart TV, Chromecast)
- ⚙️ Настройка параметров блокировки
- 📊 Статистика пропущенных сегментов
- 🌐 Удаленное управление через сервер

## Установка

### 1. Установка сервера

Сервер нужно запустить на компьютере в вашей локальной сети.

#### Вариант А: Использование готового сервера

```bash
# Клонируйте репозиторий с сервером
git clone https://github.com/username/isponsorblock-server
cd isponsorblock-server

# Установите зависимости
npm install

# Запустите сервер
npm start
```

#### Вариант Б: Простой Python сервер (для тестирования)

Создайте файл `server.py`:

```python
#!/usr/bin/env python3
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import time

class SponsorBlockHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
            
        elif path == '/devices':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            devices = [
                {"id": "1", "name": "Apple TV (Гостиная)", "type": "apple_tv", "status": "connected"},
                {"id": "2", "name": "Samsung TV (Спальня)", "type": "samsung_tv", "status": "connected"}
            ]
            self.wfile.write(json.dumps(devices).encode())
            
        elif path == '/stats':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            stats = {"segmentsSkipped": 127, "timeSaved": 2547}
            self.wfile.write(json.dumps(stats).encode())
            
        elif path == '/settings':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            settings = {
                "sponsorBlockEnabled": True,
                "adBlockEnabled": False,
                "autoSkipEnabled": True,
                "skipCategories": ["sponsor", "intro", "outro"]
            }
            self.wfile.write(json.dumps(settings).encode())
    
    def do_POST(self):
        if self.path == '/settings':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            settings = json.loads(post_data.decode('utf-8'))
            
            print(f"Получены новые настройки: {settings}")
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"success": True}).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), SponsorBlockHandler)
    print("Сервер запущен на http://0.0.0.0:8000")
    print("Для остановки нажмите Ctrl+C")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nСервер остановлен")
        server.shutdown()
```

Запустите сервер:

```bash
python3 server.py
```

#### Вариант В: Docker (рекомендуется)

Создайте `docker-compose.yml`:

```yaml
version: '3.8'
services:
  isponsorblock:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
    environment:
      - NODE_ENV=production
    restart: unless-stopped
```

Запустите:

```bash
docker-compose up -d
```

### 2. Установка iOS приложения

#### Для TrollStore (рекомендуется)

1. Скачайте готовый IPA файл из [Releases](../../releases)
2. Установите через TrollStore

#### Сборка из исходного кода

1. Клонируйте репозиторий
2. Запустите GitHub Actions workflow "Build TrollStore IPA"
3. Скачайте собранный IPA файл
4. Установите через TrollStore

## Настройка

### 1. Настройка сервера

После запуска сервера он будет доступен по адресу:
- Локальная сеть: `http://YOUR_COMPUTER_IP:8000`
- Localhost: `http://localhost:8000`

Узнать IP адрес компьютера:

**macOS/Linux:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**Windows:**
```cmd
ipconfig | findstr "IPv4"
```

### 2. Настройка iOS приложения

1. Откройте приложение iSponsorBlockTV
2. Введите адрес сервера: `http://YOUR_COMPUTER_IP:8000`
3. Нажмите "Подключиться"
4. Настройте параметры блокировки

## Использование

### Автоматический запуск сервера

Чтобы не запускать сервер вручную каждый раз:

#### macOS (LaunchAgent)

Создайте файл `~/Library/LaunchAgents/com.isponsorblock.server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.isponsorblock.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/path/to/your/server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Загрузите службу:
```bash
launchctl load ~/Library/LaunchAgents/com.isponsorblock.server.plist
```

#### Windows (Автозагрузка)

1. Создайте `.bat` файл:
```batch
@echo off
cd /d "C:\path\to\your\server"
python server.py
pause
```

2. Добавьте ярлык в папку автозагрузки:
   - Нажмите `Win + R`
   - Введите `shell:startup`
   - Скопируйте ярлык `.bat` файла

#### Linux (systemd)

Создайте файл `/etc/systemd/system/isponsorblock.service`:

```ini
[Unit]
Description=iSponsorBlockTV Server
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/path/to/your/server
ExecStart=/usr/bin/python3 /path/to/your/server.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Включите службу:
```bash
sudo systemctl enable isponsorblock.service
sudo systemctl start isponsorblock.service
```

### Настройка устройств

#### Apple TV

1. Убедитесь, что Apple TV подключен к той же сети
2. Установите приложение для блокировки рекламы (если доступно)
3. Настройте прокси: Настройки → Основные → Сеть → Wi-Fi → Настроить DNS → Вручную → `YOUR_SERVER_IP`

#### Smart TV

Настройте DNS в настройках сети телевизора:
- Первичный DNS: `YOUR_SERVER_IP`
- Вторичный DNS: `8.8.8.8`

## FAQ

**Q: В чем разница между iOS клиентом и тестовым сервером?**

A: 
- **iOS клиент** (`README_iOS_CLIENT.md`) - полноценное мобильное приложение для подключения к YouTube TV, как в оригинальном iSponsorBlockTV
- **Тестовый сервер** (`server.py`) - демо для проверки интерфейса с тестовыми данными

**Q: Что за устройства показываются в тестовом интерфейсе?**

A: Это тестовые данные для демонстрации интерфейса. В файле `server.py` в строках 17-21 вы можете изменить список устройств под свои реальные устройства.

**Q: Нужно ли каждый раз запускать сервер?**

A: Если настроить автоматический запуск (см. выше), то нет. Сервер будет запускаться автоматически при включении компьютера.

**Q: Работает ли без интернета?**

A: Базовая функциональность работает в локальной сети без интернета. Для получения данных о спонсорских сегментах нужен доступ к SponsorBlock API.

**Q: Можно ли использовать на нескольких устройствах одновременно?**

A: Да, один сервер может обслуживать несколько устройств в сети.

**Q: Как обновить список заблокированных сегментов?**

A: Сервер автоматически обновляет данные с SponsorBlock API каждые 30 минут.

## Разработка

### Структура проекта

```
iSponsorBlockTV/
├── iSponsorBlockTV/
│   ├── AppDelegate.swift          # Главный делегат приложения
│   ├── ViewController.swift       # Основной контроллер интерфейса
│   ├── NetworkManager.swift       # Менеджер сетевых запросов
│   ├── Info.plist                # Настройки приложения
│   └── Assets.xcassets/          # Ресурсы приложения
├── .github/workflows/            # GitHub Actions для автосборки
├── create_project.sh             # Скрипт создания Xcode проекта
├── create_entitlements.sh        # Скрипт создания entitlements
└── project.yml                   # Конфигурация XcodeGen
```

### Локальная разработка

1. Клонируйте репозиторий
2. Запустите `./create_project.sh`
3. Откройте `iSponsorBlockTV.xcodeproj` в Xcode
4. Внесите изменения
5. Соберите и протестируйте

## Лицензия

MIT License. См. файл LICENSE для подробностей.

## Поддержка

Если у вас возникли проблемы:

1. Проверьте, что сервер запущен и доступен
2. Убедитесь, что устройства находятся в одной сети
3. Проверьте настройки брандмауэра
4. Создайте issue в этом репозитории 
