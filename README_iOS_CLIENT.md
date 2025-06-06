# 📱 iSponsorBlockTV - iOS Client

**Полноценный iOS клиент для блокировки спонсоров и рекламы на YouTube TV устройствах**

🔴 **Логотип:** Красный круг "NO TO RACISM" - против дискриминации и за равенство!

## 🎯 Что это такое?

Это мобильная версия [оригинального iSponsorBlockTV](https://github.com/dmunozv04/iSponsorBlockTV), которая позволяет:

- ✅ **Подключаться к YouTube TV** через код связывания (как в оригинале)
- ✅ **Автоматически пропускать спонсорские сегменты** используя базу данных SponsorBlock
- ✅ **Блокировать рекламу** YouTube на телевизоре
- ✅ **Сканировать сеть** для поиска совместимых устройств
- ✅ **Работать автономно** - не нужен компьютер!

## 🚀 Установка

### Через TrollStore (Рекомендуется)

1. **Получить IPA файл:**
   ```bash
   # Скачать готовый IPA из Releases
   # ИЛИ собрать самостоятельно:
   git clone https://github.com/ваш-репозиторий/iSponsorBlockTV-iOS
   cd iSponsorBlockTV-iOS
   ./build_ipa.sh
   ```

2. **Установить через TrollStore:**
   - Скопируйте `iSponsorBlockTV.ipa` на iPhone
   - Откройте файл в TrollStore
   - Нажмите "Install"

### Через Xcode (Разработчики)

```bash
git clone https://github.com/ваш-репозиторий/iSponsorBlockTV-iOS
cd iSponsorBlockTV-iOS
xcodegen generate
open iSponsorBlockTV.xcodeproj
```

## 📺 Подключение к телевизору

### Способ 1: Код связывания (Основной)

1. **На телевизоре:**
   - Откройте приложение **YouTube**
   - Перейдите в **Настройки** → **Связать с телефоном**
   - Запомните код (например: `ABC-XYZ-123`)

2. **В iOS приложении:**
   - Введите код в поле "Введите код с телевизора"
   - Нажмите **"Подключиться к TV"**
   - Дождитесь подтверждения подключения

### Способ 2: Сканирование сети

1. Убедитесь что iPhone и TV в одной Wi-Fi сети
2. Нажмите **"Сканировать сеть"**
3. Приложение найдет совместимые устройства автоматически

**Улучшения сканирования:**
- ✅ Демонстрационные устройства для тестирования интерфейса
- ✅ SSDP поиск с расширенными параметрами
- ✅ Сканирование популярных IP диапазонов
- ✅ Подробные логи для отладки

## ⚙️ Настройки

### Автоматический пропуск
- **Включено:** Сегменты пропускаются без уведомлений
- **Выключено:** Показывается кнопка "Пропустить сегмент"

### Заглушение рекламы
- Автоматически отключает звук во время рекламных роликов

### Категории для пропуска
- **Спонсорские сегменты:** Реклама товаров/услуг
- **Вступления:** Интро видео
- **Концовки:** Аутро видео  
- **Призывы к действию:** "Подпишитесь", "Поставьте лайк"
- **Саморекламы:** Реклама других видео автора

## 📊 Статистика

Приложение показывает:
- **Текущее видео:** Название и количество найденных сегментов
- **Пропущено сегментов:** Общее количество
- **Сэкономлено времени:** В часах и минутах

## 🔧 Совместимость

### Поддерживаемые устройства:
- ✅ **Samsung Smart TV** (Tizen OS)
- ✅ **LG Smart TV** (webOS) 
- ✅ **Android TV / Google TV**
- ✅ **Apple TV** (через AirPlay)
- ✅ **Chromecast**
- ✅ **Roku** (частично)

### Требования:
- **iOS 14.0+**
- **Wi-Fi сеть** (iPhone и TV в одной сети)
- **YouTube Premium** (рекомендуется)

## 🛠️ Разработка

### Архитектура

```
📱 iOS App
├── 🎮 ViewController.swift      # Главный интерфейс
├── 📡 YouTubeTVManager.swift    # Подключение к TV
├── ⚙️ YouTubeTVSettings.swift   # Настройки и модели
├── 🌐 NetworkManager.swift      # Сеть (оставлен для совместимости)
└── 📋 Info.plist               # Конфигурация
```

### Как это работает

1. **Поиск устройств:** SSDP + mDNS сканирование
2. **Подключение:** YouTube TV Lounge API 
3. **Мониторинг:** Периодические запросы состояния
4. **Блокировка:** SponsorBlock API + команды пропуска

### API Endpoints

```swift
// YouTube TV Pairing
POST https://www.youtube.com/api/lounge/pairing/get_lounge_token_batch

// SponsorBlock Segments  
GET https://sponsor.ajay.app/api/skipSegments?videoID={id}

// Device Discovery
UDP 239.255.255.250:1900 (SSDP)
mDNS _googlecast._tcp
```

## 🐛 Отладка

### Частые проблемы:

**"Устройства не найдены"**
- Проверьте Wi-Fi сеть (должна быть одна для iPhone и TV)
- Убедитесь что TV поддерживает Google Cast
- Перезапустите приложение YouTube на TV

**"Неверный код TV"**
- Код действует только 10 минут
- Вводите код БЕЗ дефисов: `ABCXYZ123`
- Попробуйте получить новый код

**"Сегменты не пропускаются"**
- Включите "Автоматический пропуск" в настройках
- Проверьте что видео есть в базе SponsorBlock
- Убедитесь что TV подключен (зеленый статус)

### Логи

```bash
# Просмотр логов в Xcode
# Window → Devices and Simulators → Ваш iPhone → Open Console
# Фильтр: iSponsorBlockTV
```

## 📄 Лицензия

MIT License - используйте как хотите!

## 🤝 Вклад в проект

1. Fork репозитория
2. Создайте ветку: `git checkout -b feature/amazing-feature`
3. Внесите изменения и комментарии
4. Push: `git push origin feature/amazing-feature`
5. Создайте Pull Request

## ❤️ Благодарности

- [dmunozv04/iSponsorBlockTV](https://github.com/dmunozv04/iSponsorBlockTV) - Оригинальный проект
- [SponsorBlock](https://sponsor.ajay.app/) - База данных сегментов
- [YouTube TV API](https://developers.google.com/youtube/) - Документация API

---

**⭐ Если проект помог - поставьте звездочку!** 
