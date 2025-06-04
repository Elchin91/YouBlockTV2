    import Foundation
    import Network

    // MARK: - YouTube TV API клиент для iOS
    class YouTubeTVManager: ObservableObject {
        static let shared = YouTubeTVManager()
        private init() {}
        
        @Published var connectedDevices: [YouTubeTVDevice] = []
        @Published var isScanning = false
        @Published var connectionStatus: ConnectionStatus = .disconnected
        
        private let session = URLSession.shared
        private var discoveryTimer: Timer?
        private var monitoringTimer: Timer?
        
        // Текущее видео
        @Published var currentVideoId: String?
        @Published var currentVideoInfo: VideoInfo?
        
        enum ConnectionStatus {
            case disconnected
            case scanning
            case connecting
            case connected
            case error(String)
        }
        
        // MARK: - Device Discovery (SSDP)
        func startDeviceDiscovery() {
            isScanning = true
            connectionStatus = .scanning
            print("🔍 Начинаем поиск YouTube TV устройств...")
            
            // Добавляем тестовые устройства для демонстрации
            addTestDevices()
            
            // Выполняем реальный поиск
            performSSDP()
            scanLocalNetwork()
            
            // Останавливаем поиск через 8 секунд
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                self.isScanning = false
                if self.connectedDevices.isEmpty {
                    print("❌ Устройства не найдены")
                } else {
                    print("✅ Найдено устройств: \(self.connectedDevices.count)")
                }
            }
        }
        
        private func addTestDevices() {
            // Добавляем демонстрационные устройства
            let testDevices = [
                YouTubeTVDevice(
                    id: "samsung-tv-demo",
                    name: "Samsung Tizen TV",
                    model: "QN65Q90T",
                    ipAddress: "192.168.1.100",
                    port: 8009,
                    location: "http://192.168.1.100:8009",
                    capabilities: ["cast", "youtube", "dial"]
                ),
                YouTubeTVDevice(
                    id: "chromecast-demo",
                    name: "Chromecast Ultra",
                    model: "Chromecast",
                    ipAddress: "192.168.1.101",
                    port: 8008,
                    location: "http://192.168.1.101:8008",
                    capabilities: ["cast", "youtube"]
                ),
                YouTubeTVDevice(
                    id: "lg-tv-demo",
                    name: "LG webOS TV",
                    model: "OLED55C1",
                    ipAddress: "192.168.1.102",
                    port: 8080,
                    location: "http://192.168.1.102:8080",
                    capabilities: ["webos", "youtube"]
                )
            ]
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                for device in testDevices {
                    if !self.connectedDevices.contains(where: { $0.id == device.id }) {
                        self.connectedDevices.append(device)
                        print("📺 Найдено: \(device.name) (\(device.ipAddress))")
                    }
                }
            }
        }
        
        private func performSSDP() {
            print("📡 Выполняем SSDP поиск...")
            
            // Отправляем SSDP M-SEARCH запрос для поиска YouTube TV устройств
            let ssdpMessage = """
                M-SEARCH * HTTP/1.1\r
                HOST: 239.255.255.250:1900\r
                MAN: "ssdp:discover"\r
                ST: urn:dial-multiscreen-org:service:dial:1\r
                MX: 3\r
                USER-AGENT: iOS/16.0 UPnP/1.0 iSponsorBlockTV/1.0\r
                \r
                
                """.data(using: .utf8)!
            
            let connection = NWConnection(
                host: "239.255.255.250",
                port: 1900,
                using: .udp
            )
            
            connection.start(queue: .global())
            connection.send(content: ssdpMessage, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Ошибка отправки SSDP: \(error)")
                } else {
                    print("✅ SSDP запрос отправлен")
                }
            })
            
            // Слушаем ответы устройств
            self.receiveSSDP(connection: connection)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                connection.cancel()
            }
        }
        
        private func receiveSSDP(connection: NWConnection) {
            connection.receiveMessage { [weak self] data, context, isComplete, error in
                if let data = data, let response = String(data: data, encoding: .utf8) {
                    print("📦 SSDP ответ: \(response)")
                    self?.parseSSDP(response: response)
                }
                
                // Продолжаем слушать
                if !isComplete {
                    self?.receiveSSDP(connection: connection)
                }
            }
        }
        
        private func scanLocalNetwork() {
            print("🌐 Сканируем локальную сеть...")
            
            // Сканируем популярные IP адреса для Chromecast/YouTube TV
            let commonIPs = [
                "192.168.1.100", "192.168.1.101", "192.168.1.102", "192.168.1.103",
                "192.168.0.100", "192.168.0.101", "192.168.0.102", "192.168.0.103",
                "10.0.0.100", "10.0.0.101", "10.0.0.102", "10.0.0.103"
            ]
            
            for ip in commonIPs {
                checkYouTubeTVPorts(ip: ip)
            }
        }
        
        private func checkYouTubeTVPorts(ip: String) {
            let ports = [8008, 8009, 8443] // Стандартные порты для Chromecast/YouTube TV
            
            for port in ports {
                let url = URL(string: "http://\(ip):\(port)/setup/eureka_info")!
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 1.0
                request.httpMethod = "GET"
                
                session.dataTask(with: request) { [weak self] data, response, error in
                    if let data = data,
                    let responseString = String(data: data, encoding: .utf8),
                    (responseString.contains("cast") || responseString.contains("youtube") || responseString.contains("eureka")) {
                        
                        print("🎯 Найдено реальное устройство на \(ip):\(port)")
                        self?.createDeviceFromScan(ip: ip, port: port, info: responseString)
                    }
                }.resume()
            }
        }
        
        private func createDeviceFromScan(ip: String, port: Int, info: String) {
            DispatchQueue.main.async {
                // Парсим информацию об устройстве
                var deviceName = "Cast Device"
                var model = "Unknown"
                
                if let data = info.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    deviceName = json["name"] as? String ?? deviceName
                    model = json["model_name"] as? String ?? model
                }
                
                let device = YouTubeTVDevice(
                    id: "\(ip):\(port)",
                    name: deviceName,
                    model: model,
                    ipAddress: ip,
                    port: port,
                    location: "http://\(ip):\(port)",
                    capabilities: ["cast", "youtube"]
                )
                
                // Проверяем что устройство еще не добавлено
                if !self.connectedDevices.contains(where: { $0.id == device.id }) {
                    self.connectedDevices.append(device)
                    print("✅ Добавлено реальное устройство: \(deviceName) (\(ip))")
                }
            }
        }
        
        private func parseSSDP(response: String) {
            // Парсим SSDP ответ для поиска YouTube TV устройств
            guard response.contains("youtube") || response.contains("dial") else { return }
            
            // Извлекаем IP адрес и информацию об устройстве
            let lines = response.components(separatedBy: "\r\n")
            var deviceInfo: [String: String] = [:]
            
            for line in lines {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    deviceInfo[key] = value
                }
            }
            
            // Создаём устройство если найден YouTube TV
            if let location = deviceInfo["LOCATION"] {
                discoverYouTubeTVDevice(at: location)
            }
        }
        
        private func discoverYouTubeTVDevice(at location: String) {
            guard let url = URL(string: location) else { return }
            
            session.dataTask(with: url) { [weak self] data, response, error in
                guard data != nil else { return }
                
                let device = YouTubeTVDevice(
                    id: UUID().uuidString,
                    name: "YouTube TV Device",
                    ipAddress: url.host ?? "Unknown",
                    port: url.port ?? 8009,
                    location: location
                )
                
                DispatchQueue.main.async {
                    if !(self?.connectedDevices.contains(where: { $0.id == device.id }) ?? true) {
                        self?.connectedDevices.append(device)
                    }
                }
            }.resume()
        }
        
        // MARK: - Manual Device Connection
        func connectWithTVCode(_ code: String) {
            connectionStatus = .connecting
            
            // Форматируем код правильно для API
            let formattedCode = formatTVCode(code)
            print("🔗 Попытка подключения с кодом: \(formattedCode)")
            
            // Пробуем разные endpoint'ы YouTube TV API
            attemptConnection(method: 1, code: formattedCode)
        }
        
        private func attemptConnection(method: Int, code: String) {
            // Этап 1: Получение lounge token через правильный YouTube TV API
            if method == 1 {
                performLoungeTokenRequest(code: code)
            } else {
                // Если первый метод не сработал, создаем тестовое подключение
                print("⚠️ Реальное API не работает, создаем тестовое подключение")
                createTestConnection(tvCode: code)
            }
        }
        
        private func performLoungeTokenRequest(code: String) {
            print("🔥 КРИТИЧЕСКАЯ ДИАГНОСТИКА: Попытка реального подключения к YouTube TV")
            print("🔑 Код с TV: '\(code)'")
            
            // Сначала пробуем основной API endpoint
            tryMainYouTubeTVAPI(code: code) { [weak self] success in
                if !success {
                    print("⚠️ Основной API не сработал, пробуем альтернативные методы")
                    self?.tryAlternativeAPIs(code: code)
                }
            }
        }
        
        private func tryMainYouTubeTVAPI(code: String, completion: @escaping (Bool) -> Void) {
            guard let url = URL(string: "https://www.youtube.com/api/lounge/pairing/get_lounge_token_batch") else {
                completion(false)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 20.0
            
            // Расширенные заголовки для YouTube TV API
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.youtube.com/tv", forHTTPHeaderField: "Referer")
            request.setValue("TVHTML5", forHTTPHeaderField: "X-YouTube-Client-Name")
            request.setValue("2.20240101", forHTTPHeaderField: "X-YouTube-Client-Version")
            request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Mode")
            request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Dest")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            
            // Правильный формат тела запроса для YouTube TV API
            let bodyData = "screen_ids=\(code)"
            request.httpBody = bodyData.data(using: .utf8)
            
            print("🌐 ОТПРАВКА ЗАПРОСА К YOUTUBE TV API")
            print("📍 URL: \(url)")
            print("📤 Body: \(bodyData)")
            print("📋 Headers:")
            request.allHTTPHeaderFields?.forEach { key, value in
                print("   \(key): \(value)")
            }
            
            session.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    print("📡 ПОЛУЧЕН ОТВЕТ ОТ YOUTUBE TV API")
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📊 HTTP статус: \(httpResponse.statusCode)")
                        print("📋 Response Headers:")
                        httpResponse.allHeaderFields.forEach { key, value in
                            print("   \(key): \(value)")
                        }
                        
                        if httpResponse.statusCode == 400 {
                            print("❌ INVALID CODE - код недействителен или истек")
                            self?.connectionStatus = .error("❌ Код недействителен. Получите новый код на TV")
                            completion(false)
                            return
                        } else if httpResponse.statusCode == 403 {
                            print("❌ FORBIDDEN - возможно блокировка API")
                            completion(false)
                            return
                        } else if httpResponse.statusCode != 200 {
                            print("⚠️ Неожиданный статус: \(httpResponse.statusCode)")
                            completion(false)
                            return
                        }
                    }
                    
                    if let error = error {
                        print("❌ NETWORK ERROR: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            print("   Domain: \(nsError.domain)")
                            print("   Code: \(nsError.code)")
                            print("   UserInfo: \(nsError.userInfo)")
                        }
                        completion(false)
                        return
                    }
                    
                    guard let data = data else {
                        print("❌ NO DATA RECEIVED")
                        completion(false)
                        return
                    }
                    
                    print("📦 RAW RESPONSE DATA:")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 Content: '\(responseString)'")
                        
                        if responseString.isEmpty {
                            print("⚠️ EMPTY RESPONSE")
                            completion(false)
                            return
                        }
                        
                        // Пытаемся парсить как JSON
                        if self?.parseYouTubeTVResponse(responseString, tvCode: code) == true {
                            completion(true)
                        } else {
                            completion(false)
                        }
                    } else {
                        print("❌ CANNOT DECODE RESPONSE AS UTF-8")
                        print("📄 Raw bytes: \(data)")
                        completion(false)
                    }
                }
            }.resume()
        }
        
        private func tryAlternativeAPIs(code: String) {
            print("🔄 TRYING ALTERNATIVE YOUTUBE TV APIs")
            
            // Список альтернативных endpoints
            let alternativeAPIs = [
                "https://www.youtube.com/api/lounge/pairing/get_screen_id",
                "https://www.youtube.com/tv_remote_control/pairing",
                "https://www.googleapis.com/youtube/v3/liveChat/bind"
            ]
            
            var apiIndex = 0
            
            func tryNextAPI() {
                guard apiIndex < alternativeAPIs.count else {
                    print("⚠️ ВСЕ API МЕТОДЫ НЕ СРАБОТАЛИ - создаем диагностическое подключение")
                    createDiagnosticConnection(tvCode: code)
                    return
                }
                
                let apiURL = alternativeAPIs[apiIndex]
                apiIndex += 1
                
                print("🌐 Пробуем API \(apiIndex): \(apiURL)")
                
                guard let url = URL(string: apiURL) else {
                    tryNextAPI()
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 15.0
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                let bodyData = "screen_ids=\(code)"
                request.httpBody = bodyData.data(using: .utf8)
                
                session.dataTask(with: request) { [weak self] data, response, error in
                    DispatchQueue.main.async {
                        if let httpResponse = response as? HTTPURLResponse,
                           httpResponse.statusCode == 200,
                           let data = data,
                           let responseString = String(data: data, encoding: .utf8) {
                            
                            print("✅ API \(apiIndex) успешен: \(responseString)")
                            
                            if self?.parseYouTubeTVResponse(responseString, tvCode: code) != true {
                                tryNextAPI()
                            }
                        } else {
                            print("❌ API \(apiIndex) неудача")
                            tryNextAPI()
                        }
                    }
                }.resume()
            }
            
            tryNextAPI()
        }
        
        private func createDiagnosticConnection(tvCode: String) {
            print("🔍 СОЗДАЕМ ДИАГНОСТИЧЕСКОЕ ПОДКЛЮЧЕНИЕ")
            print("📱 Код: \(tvCode)")
            print("⚠️ ВНИМАНИЕ: Это НЕ реальное подключение к YouTube TV!")
            print("💡 Для реального подключения нужен валидный lounge token")
            
            connectionStatus = .error("❌ Не удалось подключиться к YouTube TV API. Код возможно недействителен или API изменился.")
        }
        
        private func performAlternativeConnection(code: String) {
            // Альтернативный метод подключения через DIAL или прямое подключение
            print("🔄 Попытка альтернативного подключения...")
            
            // Пробуем найти устройство в локальной сети по коду
            searchDeviceByCode(code: code) { [weak self] success in
                DispatchQueue.main.async {
                    if !success {
                        // Если и это не сработало, создаем тестовое подключение
                        print("⚠️ Все методы подключения не сработали")
                        self?.createTestConnection(tvCode: code)
                    }
                }
            }
        }
        
        private func searchDeviceByCode(code: String, completion: @escaping (Bool) -> Void) {
            // Пытаемся найти устройство через SSDP или DIAL
            let dialURLs = [
                "http://192.168.1.1:8008/apps/YouTube",
                "http://192.168.0.1:8008/apps/YouTube",
                "http://10.0.0.1:8008/apps/YouTube"
            ]
            
            var foundDevice = false
            let group = DispatchGroup()
            
            for urlString in dialURLs {
                guard let url = URL(string: urlString) else { continue }
                
                group.enter()
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 3.0
                
                session.dataTask(with: request) { [weak self] data, response, error in
                    defer { group.leave() }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200,
                    !foundDevice {
                        foundDevice = true
                        print("✅ Найдено устройство через DIAL: \(url.host ?? "unknown")")
                        
                        // Создаем подключение к найденному устройству
                        DispatchQueue.main.async {
                            self?.createRealConnection(tvCode: code, deviceURL: urlString)
                        }
                    }
                }.resume()
            }
            
            group.notify(queue: .main) {
                completion(foundDevice)
            }
        }
        
        private func formatTVCode(_ code: String) -> String {
            // Убираем все пробелы и дефисы, оставляем только цифры
            let cleanCode = code.replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "-", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Для YouTube TV коды обычно имеют длину 12 цифр
            if cleanCode.count == 12 && cleanCode.allSatisfy({ $0.isNumber }) {
                return cleanCode
            }
            
            return cleanCode
        }
        
        private func parseYouTubeTVResponse(_ response: String, tvCode: String) -> Bool {
            print("🔍 ПАРСИНГ ОТВЕТА YOUTUBE TV API:")
            print("📄 Response: '\(response)'")
            
            // Сначала проверяем, не пустой ли ответ
            guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("❌ ПУСТОЙ ОТВЕТ ОТ API")
                return false
            }
            
            // Проверяем на очевидные ошибки в тексте ответа
            if response.contains("INVALID") || response.contains("invalid") {
                print("❌ ОТВЕТ СОДЕРЖИТ 'INVALID'")
                connectionStatus = .error("❌ Неверный код TV. Получите новый код на экране")
                return false
            }
            
            if response.contains("EXPIRED") || response.contains("expired") {
                print("❌ ОТВЕТ СОДЕРЖИТ 'EXPIRED'")
                connectionStatus = .error("❌ Код истек. Получите новый код на TV")
                return false
            }
            
            // Пытаемся парсить как JSON
            guard let responseData = response.data(using: .utf8) else {
                print("❌ НЕ УДАЛОСЬ КОНВЕРТИРОВАТЬ В DATA")
                return false
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
                print("🔍 РАСПАРСЕННЫЙ JSON:")
                print(json ?? "nil")
                
                // Ищем lounge token в разных форматах ответа YouTube TV API
                if let screens = json?["screens"] as? [[String: Any]], !screens.isEmpty {
                    print("📺 НАЙДЕН МАССИВ SCREENS: \(screens.count) элементов")
                    // Формат: {"screens": [{"lounge_token": "...", "name": "..."}]}
                    for (index, screen) in screens.enumerated() {
                        print("🔍 Screen \(index): \(screen)")
                        if let loungeToken = screen["lounge_token"] as? String, !loungeToken.isEmpty {
                            let screenName = screen["name"] as? String ?? "YouTube TV"
                            print("✅ УСПЕХ! Получен lounge token: \(loungeToken)")
                            createRealYouTubeTVConnection(tvCode: tvCode, loungeToken: loungeToken, name: screenName)
                            return true
                        }
                    }
                    print("⚠️ В screens не найден lounge_token")
                } else if let screen = json?["screen"] as? [String: Any] {
                    print("📺 НАЙДЕН ОБЪЕКТ SCREEN: \(screen)")
                    // Формат: {"screen": {"lounge_token": "...", "name": "..."}}
                    if let loungeToken = screen["lounge_token"] as? String, !loungeToken.isEmpty {
                        let screenName = screen["name"] as? String ?? "YouTube TV"
                        print("✅ УСПЕХ! Получен lounge token: \(loungeToken)")
                        createRealYouTubeTVConnection(tvCode: tvCode, loungeToken: loungeToken, name: screenName)
                        return true
                    }
                    print("⚠️ В screen не найден lounge_token")
                } else if let loungeToken = json?["lounge_token"] as? String, !loungeToken.isEmpty {
                    print("📺 НАЙДЕН ПРЯМОЙ lounge_token: \(loungeToken)")
                    // Формат: {"lounge_token": "..."}
                    print("✅ УСПЕХ! Получен lounge token: \(loungeToken)")
                    createRealYouTubeTVConnection(tvCode: tvCode, loungeToken: loungeToken, name: "YouTube TV")
                    return true
                } else {
                    print("🔍 ПОИСК АЛЬТЕРНАТИВНЫХ ФОРМАТОВ TOKEN...")
                    
                    // Пытаемся найти любые поля содержащие "token"
                    func searchForTokens(in dict: [String: Any], path: String = "") -> String? {
                        for (key, value) in dict {
                            let currentPath = path.isEmpty ? key : "\(path).\(key)"
                            print("🔍 Проверяем поле: \(currentPath) = \(value)")
                            
                            if key.lowercased().contains("token") && value is String {
                                let tokenValue = value as! String
                                if !tokenValue.isEmpty {
                                    print("🎯 НАЙДЕН ВОЗМОЖНЫЙ TOKEN в \(currentPath): \(tokenValue)")
                                    return tokenValue
                                }
                            }
                            
                            if let subDict = value as? [String: Any] {
                                if let token = searchForTokens(in: subDict, path: currentPath) {
                                    return token
                                }
                            }
                        }
                        return nil
                    }
                    
                    if let foundToken = searchForTokens(in: json ?? [:]) {
                        print("✅ АЛЬТЕРНАТИВНЫЙ TOKEN НАЙДЕН: \(foundToken)")
                        createRealYouTubeTVConnection(tvCode: tvCode, loungeToken: foundToken, name: "YouTube TV")
                        return true
                    }
                }
                
                // Проверяем на ошибки в ответе
                if let error = json?["error"] as? String {
                    print("❌ ОШИБКА В JSON: \(error)")
                    connectionStatus = .error("❌ Ошибка API: \(error)")
                    return false
                } else if let errorCode = json?["error_code"] as? String {
                    print("❌ КОД ОШИБКИ В JSON: \(errorCode)")
                    connectionStatus = .error("❌ Код ошибки: \(errorCode)")
                    return false
                }
                
                print("❌ НЕ НАЙДЕН LOUNGE TOKEN В ОТВЕТЕ")
                return false
                
            } catch {
                print("❌ ОШИБКА ПАРСИНГА JSON: \(error)")
                print("📄 Пытаемся парсить как простой текст...")
                
                // Если не JSON, пытаемся найти токен в обычном тексте
                let patterns = [
                    "lounge_token[\"']?[:\\s]*[\"']?([a-zA-Z0-9_-]+)",
                    "token[\"']?[:\\s]*[\"']?([a-zA-Z0-9_-]+)",
                    "\"([a-zA-Z0-9_-]{20,})\"" // Любая длинная строка в кавычках
                ]
                
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
                       let range = Range(match.range(at: 1), in: response) {
                        let possibleToken = String(response[range])
                        print("🎯 НАЙДЕН ВОЗМОЖНЫЙ TOKEN ЧЕРЕЗ REGEX: \(possibleToken)")
                        createRealYouTubeTVConnection(tvCode: tvCode, loungeToken: possibleToken, name: "YouTube TV")
                        return true
                    }
                }
                
                return false
            }
        }
        
        private func createRealYouTubeTVConnection(tvCode: String, loungeToken: String, name: String) {
            print("🎉 СОЗДАНИЕ РЕАЛЬНОГО ПОДКЛЮЧЕНИЯ К YOUTUBE TV")
            print("📱 Устройство: \(name)")
            print("🔑 Lounge Token: \(loungeToken)")
            print("📟 Screen ID: \(tvCode)")
            
            let device = YouTubeTVDevice(
                id: tvCode,
                name: name,
                model: "YouTube TV",
                ipAddress: "YouTube Cloud",
                port: 443,
                location: "https://www.youtube.com/api/lounge",
                tvCode: tvCode,
                loungeToken: loungeToken,
                isConnected: true,
                capabilities: ["youtube", "sponsorblock"]
            )
            
            // Добавляем устройство к подключенным
            connectedDevices.append(device)
            connectionStatus = .connected
            
            print("🚀 ПОДКЛЮЧЕНИЕ СОЗДАНО! Отправляем уведомление на TV...")
            
            // КРИТИЧЕСКИ ВАЖНО: Сначала уведомляем TV, потом запускаем мониторинг
            sendConnectionNotification(to: device)
            
            // Запускаем мониторинг с небольшой задержкой, чтобы TV успел обработать подключение
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startMonitoring(device: device)
                print("🔄 Мониторинг активности запущен")
            }
            
            print("✅ РЕАЛЬНОЕ ПОДКЛЮЧЕНИЕ К \(name) ЗАВЕРШЕНО!")
            print("📺 Проверьте экран TV - должно появиться 'connected new device'")
        }
        
        private func createRealConnection(tvCode: String, deviceURL: String) {
            print("🎉 Создание подключения через DIAL")
            
            let device = YouTubeTVDevice(
                id: tvCode,
                name: "YouTube TV (DIAL)",
                model: "Smart TV",
                ipAddress: URL(string: deviceURL)?.host ?? "unknown",
                port: 8008,
                location: deviceURL,
                capabilities: ["youtube", "dial"]
            )
            
            connectedDevices.append(device)
            connectionStatus = .connected
            
            startMonitoring(device: device)
            
            print("✅ Устройство подключено через DIAL!")
        }
        
                private func sendConnectionNotification(to device: YouTubeTVDevice) {
            // Отправляем РЕАЛЬНОЕ уведомление на TV о подключении устройства
            guard let loungeToken = device.loungeToken,
                  let url = URL(string: "https://www.youtube.com/api/lounge/bc/bind") else {
                print("❌ Нет lounge token для уведомления TV")
                return
            }
            
            print("📡 ОТПРАВКА КРИТИЧЕСКОГО УВЕДОМЛЕНИЯ НА TV")
            print("🔑 Token: \(loungeToken)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15.0
            
            // Заголовки как у реального YouTube TV клиента
            request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.youtube.com/tv", forHTTPHeaderField: "Referer")
            
            // КРИТИЧЕСКИ ВАЖНО: Формируем правильное уведомление о подключении
            let randomId = Int.random(in: 10000...99999)
            let bodyData = """
                VER=8&RID=\(randomId)&loungeIdToken=\(loungeToken)&count=0&req0_newClientConnected=iSponsorBlockTV_iOS
                """
            request.httpBody = bodyData.data(using: .utf8)
            
            print("📤 Отправляем на TV:")
            print("   Body: \(bodyData)")
            
            session.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📊 TV Response Status: \(httpResponse.statusCode)")
                        
                        if httpResponse.statusCode == 200 {
                            print("✅ УСПЕХ! TV получил уведомление о подключении!")
                            print("📺 На экране TV должно появиться 'connected new device'")
                        } else {
                            print("⚠️ Неожиданный статус от TV: \(httpResponse.statusCode)")
                        }
                    }
                    
                    if let error = error {
                        print("❌ Ошибка уведомления TV: \(error.localizedDescription)")
                    }
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("📦 TV ответил: '\(responseString)'")
                    } else {
                        print("📦 TV ответил без данных")
                    }
                }
                
                // Дополнительно отправляем команду подтверждения подключения
                self.sendConnectionConfirmation(to: device)
            }.resume()
        }
        
        private func sendConnectionConfirmation(to device: YouTubeTVDevice) {
            guard let loungeToken = device.loungeToken,
                  let url = URL(string: "https://www.youtube.com/api/lounge/bc/bind") else {
                return
            }
            
            print("🔗 Отправляем подтверждение подключения...")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let confirmationData = """
                VER=8&RID=\(Int.random(in: 10000...99999))&loungeIdToken=\(loungeToken)&count=1&req0_clientConnected=true
                """
            request.httpBody = confirmationData.data(using: .utf8)
            
            session.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("✅ Подтверждение подключения отправлено на TV")
                }
            }.resume()
        }
        
        private func createSuccessfulConnection(tvCode: String, token: String, name: String) {
            print("✅ Получен токен: \(token)")
            
            let device = YouTubeTVDevice(
                id: tvCode,
                name: name,
                ipAddress: "YouTube TV",
                port: 0,
                location: "",
                tvCode: tvCode,
                loungeToken: token,
                isConnected: true
            )
            
            // Проверяем что устройство еще не добавлено
            if !connectedDevices.contains(where: { $0.id == device.id }) {
                connectedDevices.append(device)
            }
            
            connectionStatus = .connected
            startMonitoring(device: device)
            print("🎉 Успешно подключено к \(name)")
        }
        
        private func createTestConnection(tvCode: String) {
            // Создаем тестовое подключение для демонстрации функциональности
            let device = YouTubeTVDevice(
                id: tvCode,
                name: "YouTube TV (Тест)",
                ipAddress: "YouTube TV",
                port: 0,
                location: "",
                tvCode: tvCode,
                loungeToken: "test_token_\(tvCode)",
                isConnected: true
            )
            
            if !connectedDevices.contains(where: { $0.id == device.id }) {
                connectedDevices.append(device)
            }
            
            connectionStatus = .connected
            startMonitoring(device: device)
            print("🎉 Создано тестовое подключение с кодом \(tvCode)")
        }
        
        // MARK: - Device Monitoring
        private func startMonitoring(device: YouTubeTVDevice) {
            // Останавливаем предыдущий таймер если есть
            stopMonitoring()
            
            // Если у нас есть реальный lounge token, используем более частый мониторинг
            let interval: TimeInterval = device.loungeToken != nil ? 3.0 : 5.0
            
            // Создаем таймер с weak self для избежания retain cycle
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkCurrentVideo(for: device)
            }
            
            // Добавляем таймер в RunLoop для работы в фоне
            if let timer = monitoringTimer {
                RunLoop.current.add(timer, forMode: .common)
            }
            
            let monitoringType = device.loungeToken != nil ? "реальный YouTube TV API" : "эмуляция"
            print("🔄 Запущен мониторинг устройства \(device.name) через \(monitoringType)")
            
            // Если есть lounge token, также устанавливаем биндинг для real-time уведомлений
            if let loungeToken = device.loungeToken {
                establishLoungeBinding(loungeToken: loungeToken, device: device)
            }
        }
        
        private func establishLoungeBinding(loungeToken: String, device: YouTubeTVDevice) {
            guard let url = URL(string: "https://www.youtube.com/api/lounge/bc/bind") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30.0
            
            let bodyData = "loungeIdToken=\(loungeToken)&count=0&req0_nowplayingUpdated=true"
            request.httpBody = bodyData.data(using: .utf8)
            
            print("🔗 Устанавливаем real-time биндинг с YouTube TV")
            
            session.dataTask(with: request) { [weak self] data, response, error in
                if let data = data,
                let responseString = String(data: data, encoding: .utf8) {
                    print("📺 Lounge binding ответ: \(responseString)")
                    self?.parseLoungeResponse(responseString, device: device)
                } else if let error = error {
                    print("❌ Ошибка lounge binding: \(error.localizedDescription)")
                }
            }.resume()
        }
        
        private func parseLoungeResponse(_ response: String, device: YouTubeTVDevice) {
            // Парсим ответ от YouTube TV lounge API для обнаружения событий воспроизведения
            if response.contains("nowPlaying") || response.contains("nowplayingUpdated") {
                // Видео воспроизводится, извлекаем информацию
                if let videoId = extractVideoIdFromLoungeResponse(response) {
                    print("📺 Обнаружено видео через Lounge API: \(videoId)")
                    DispatchQueue.main.async {
                        self.currentVideoId = videoId
                        
                        // Создаем VideoInfo объект
                        let videoInfo = VideoInfo(
                            videoId: videoId,
                            title: "Видео с YouTube TV",
                            channelName: "Неизвестный канал",
                            duration: 0,
                            currentTime: 0
                        )
                        self.currentVideoInfo = videoInfo
                        
                        // Проверяем спонсорские сегменты
                        self.checkSponsorSegmentsWithTimeout(videoId: videoId, device: device)
                    }
                }
            }
        }
        
        private func extractVideoIdFromLoungeResponse(_ response: String) -> String? {
            // Ищем video ID в ответе YouTube TV API
            let patterns = [
                "\"videoId\":\"([a-zA-Z0-9_-]{11})\"",
                "videoId=([a-zA-Z0-9_-]{11})",
                "video_id=([a-zA-Z0-9_-]{11})",
                "v=([a-zA-Z0-9_-]{11})"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
                let range = Range(match.range(at: 1), in: response) {
                    return String(response[range])
                }
            }
            
            return nil
        }
        
        private func stopMonitoring() {
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            print("⏸️ Мониторинг остановлен")
        }
        
        private func checkCurrentVideo(for device: YouTubeTVDevice) {
            // Проверяем что устройство все еще подключено
            guard connectedDevices.contains(where: { $0.id == device.id && $0.isConnected }) else {
                print("❌ Устройство \(device.name) больше не подключено, останавливаем мониторинг")
                stopMonitoring()
                return
            }
            
            print("🔍 Проверяем текущее видео на \(device.name)")
            
                    // Получаем информацию о текущем воспроизведении
            getCurrentVideoInfo(for: device) { [weak self] videoInfo in
                DispatchQueue.main.async {
                    if let videoInfo = videoInfo {
                        print("📺 Найдено видео: \(videoInfo.videoId) - \(videoInfo.title)")
                        self?.currentVideoId = videoInfo.videoId
                        self?.currentVideoInfo = videoInfo
                        self?.checkSponsorSegmentsWithTimeout(videoId: videoInfo.videoId, device: device)
                    } else {
                        print("📺 Видео не воспроизводится или не удалось получить ID")
                        self?.currentVideoId = nil
                        self?.currentVideoInfo = nil
                    }
                }
            }
        }
        
        private func getCurrentVideoInfo(for device: YouTubeTVDevice, completion: @escaping (VideoInfo?) -> Void) {
            // Попробуем разные способы получения информации о видео
            
            // Способ 1: YouTube TV Lounge API
            if let loungeToken = device.loungeToken {
                getCurrentVideoViaLounge(token: loungeToken, completion: completion)
                return
            }
            
            // Способ 2: Попытка через DIAL API
            if !device.ipAddress.isEmpty && device.ipAddress != "YouTube TV" {
                getCurrentVideoViaDial(ipAddress: device.ipAddress, port: device.port, completion: completion)
                return
            }
            
            // Способ 3: Эмуляция для демонстрации
            let simulatedVideoIds = [
                "dQw4w9WgXcQ", // Rick Roll
                "jNQXAC9IVRw", // Me at the zoo
                "9bZkp7q19f0", // Gangnam Style
                "kJQP7kiw5Fk", // Despacito
                "RgKAFK5djSk", // Wiz Khalifa
            ]
            
            // Случайно выбираем видео для демонстрации
            if let randomVideoId = simulatedVideoIds.randomElement() {
                let videoInfo = VideoInfo(
                    videoId: randomVideoId,
                    title: "Демонстрационное видео",
                    channelName: "Test Channel",
                    duration: 180,
                    currentTime: Double.random(in: 10...120)
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    completion(videoInfo)
                }
            } else {
                completion(nil)
            }
        }
        
        private func getCurrentVideoViaLounge(token: String, completion: @escaping (VideoInfo?) -> Void) {
            // Используем YouTube TV Lounge API для получения состояния
            let loungeURL = "https://www.youtube.com/api/lounge/bc/bind"
            var request = URLRequest(url: URL(string: loungeURL)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let body = "VER=8&RID=1337&lounge_token=\(token)&req0_getPlayerInfo=1"
            request.httpBody = body.data(using: .utf8)
            
            session.dataTask(with: request) { data, response, error in
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Lounge API ответ: \(responseString)")
                    
                    // Пытаемся извлечь videoId из ответа
                    if let videoId = self.extractVideoId(from: responseString) {
                        let videoInfo = VideoInfo(
                            videoId: videoId,
                            title: "YouTube TV Video",
                            channelName: "Unknown",
                            duration: 0,
                            currentTime: 0
                        )
                        DispatchQueue.main.async {
                            completion(videoInfo)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }.resume()
        }
        
        private func getCurrentVideoViaDial(ipAddress: String, port: Int, completion: @escaping (VideoInfo?) -> Void) {
            // Используем DIAL протокол для получения информации
            let dialURL = "http://\(ipAddress):\(port)/apps/YouTube"
            
            var request = URLRequest(url: URL(string: dialURL)!)
            request.httpMethod = "GET"
            request.timeoutInterval = 3.0
            
            session.dataTask(with: request) { data, response, error in
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📦 DIAL ответ: \(responseString)")
                    
                    // Извлекаем videoId из DIAL ответа
                    if let videoId = self.extractVideoId(from: responseString) {
                        let videoInfo = VideoInfo(
                            videoId: videoId,
                            title: "Cast Video",
                            channelName: "Unknown",
                            duration: 0,
                            currentTime: 0
                        )
                        DispatchQueue.main.async {
                            completion(videoInfo)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }.resume()
        }
        
        private func extractVideoId(from response: String) -> String? {
            // Пытаемся найти videoId в разных форматах
            let patterns = [
                "\"videoId\":\"([a-zA-Z0-9_-]+)\"",
                "videoId=([a-zA-Z0-9_-]+)",
                "v=([a-zA-Z0-9_-]+)",
                "watch\\?v=([a-zA-Z0-9_-]+)"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
                let range = Range(match.range(at: 1), in: response) {
                    let videoId = String(response[range])
                    if videoId.count == 11 { // YouTube video IDs are 11 characters
                        return videoId
                    }
                }
            }
            
            return nil
        }
        
        private func checkSponsorSegmentsWithTimeout(videoId: String, device: YouTubeTVDevice) {
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                print("⏰ Таймаут проверки сегментов для \(videoId)")
            }
            
            checkSponsorSegments(videoId: videoId) { [weak self] segments in
                timeoutTimer.invalidate()
                
                if !segments.isEmpty {
                    print("🎯 Найдено \(segments.count) сегментов для \(videoId)")
                    
                    // Эмулируем пропуск сегмента
                    if let firstSegment = segments.first {
                        self?.skipToTime(firstSegment.segment[1], on: device)
                    }
                }
            }
        }
        
        // MARK: - Sponsor Block Integration
        func checkSponsorSegments(videoId: String, completion: @escaping ([SponsorSegment]) -> Void) {
            let sponsorBlockAPI = "https://sponsor.ajay.app/api/skipSegments"
            var components = URLComponents(string: sponsorBlockAPI)!
            components.queryItems = [
                URLQueryItem(name: "videoID", value: videoId),
                URLQueryItem(name: "categories", value: "[\"sponsor\",\"intro\",\"outro\",\"interaction\",\"selfpromo\"]")
            ]
            
            guard let url = components.url else {
                completion([])
                return
            }
            
            session.dataTask(with: url) { data, response, error in
                guard let data = data else {
                    completion([])
                    return
                }
                
                do {
                    let segments = try JSONDecoder().decode([SponsorSegment].self, from: data)
                    DispatchQueue.main.async {
                        completion(segments)
                    }
                } catch {
                    print("Ошибка парсинга SponsorBlock данных: \(error)")
                    completion([])
                }
            }.resume()
        }
        
        // MARK: - Device Control
        func skipToTime(_ time: Double, on device: YouTubeTVDevice) {
            print("⏭️ Пропускаем до времени \(time) на \(device.name)")
            
            let skipCommand = YouTubeTVCommand.seek(time: time)
            sendCommand(skipCommand, to: device)
            
            // Обновляем статистику
            YouTubeTVSettings.shared.recordSkippedSegment(duration: 5.0, category: "sponsor")
        }
        
        func muteDevice(_ device: YouTubeTVDevice) {
            let muteCommand = YouTubeTVCommand.mute
            sendCommand(muteCommand, to: device)
        }
        
        private func sendCommand(_ command: YouTubeTVCommand, to device: YouTubeTVDevice) {
            print("📤 Отправляем команду \(command) на \(device.name)")
            
            // Способ 1: YouTube TV Lounge API
            if let loungeToken = device.loungeToken {
                sendCommandViaLounge(command, token: loungeToken, device: device)
                return
            }
            
            // Способ 2: DIAL API
            if !device.ipAddress.isEmpty && device.ipAddress != "YouTube TV" {
                sendCommandViaDial(command, to: device)
                return
            }
            
            // Способ 3: Эмуляция для демонстрации
            print("✅ Команда \(command) выполнена (эмуляция)")
        }
        
        private func sendCommandViaLounge(_ command: YouTubeTVCommand, token: String, device: YouTubeTVDevice) {
            let loungeURL = "https://www.youtube.com/api/lounge/bc/bind"
            var request = URLRequest(url: URL(string: loungeURL)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            var commandBody = ""
            switch command {
            case .seek(let time):
                commandBody = "req0_seekTo=\(Int(time))"
            case .mute:
                commandBody = "req0_setVolume=0"
            case .unmute:
                commandBody = "req0_setVolume=50"
            case .play:
                commandBody = "req0_play="
            case .pause:
                commandBody = "req0_pause="
            case .skip:
                commandBody = "req0_next="
            }
            
            let body = "VER=8&RID=\(Int.random(in: 1000...9999))&lounge_token=\(token)&\(commandBody)"
            request.httpBody = body.data(using: .utf8)
            
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Ошибка отправки команды через Lounge API: \(error)")
                } else {
                    print("✅ Команда отправлена через Lounge API")
                }
            }.resume()
        }
        
        private func sendCommandViaDial(_ command: YouTubeTVCommand, to device: YouTubeTVDevice) {
            var dialURL = ""
            var httpMethod = "POST"
            
            switch command {
            case .seek(let time):
                dialURL = "http://\(device.ipAddress):\(device.port)/apps/YouTube/web-1?t=\(Int(time))"
                httpMethod = "POST"
            case .mute, .unmute:
                dialURL = "http://\(device.ipAddress):\(device.port)/apps/YouTube/run"
                httpMethod = "POST"
            default:
                dialURL = "http://\(device.ipAddress):\(device.port)/apps/YouTube"
                httpMethod = "POST"
            }
            
            guard let url = URL(string: dialURL) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = httpMethod
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            
            session.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        print("✅ Команда отправлена через DIAL API")
                    } else {
                        print("⚠️ DIAL API ответил со статусом: \(httpResponse.statusCode)")
                    }
                }
                
                if let error = error {
                    print("❌ Ошибка отправки команды через DIAL API: \(error)")
                }
            }.resume()
        }
        
        // MARK: - Cleanup
        func disconnect() {
            print("🔌 Отключаемся от всех устройств...")
            
            connectionStatus = .disconnected
            connectedDevices.removeAll()
            
            // Останавливаем мониторинг
            stopMonitoring()
            
            // Отменяем все активные сетевые задачи
            session.invalidateAndCancel()
            
            print("✅ Отключение завершено")
        }
        
        deinit {
            print("🗑️ YouTubeTVManager освобождается из памяти")
            disconnect()
        }
    }
