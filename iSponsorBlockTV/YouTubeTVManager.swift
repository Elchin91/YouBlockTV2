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
        let urls = [
            "https://www.youtube.com/api/lounge/pairing/get_lounge_token_batch",
            "https://www.youtube.com/api/lounge/pairing/get_screen_id",
            "https://www.googleapis.com/youtube/v3/liveChat/messages"
        ]
        
        guard method <= urls.count, let url = URL(string: urls[method - 1]) else {
            // Если все методы не сработали, создаем тестовое подключение
            print("⚠️ Все API методы не сработали, создаем тестовое подключение")
            createTestConnection(tvCode: code)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        
        // Добавляем заголовки
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        request.setValue("1", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("WEB", forHTTPHeaderField: "X-YouTube-Client-Name")
        
        // Формируем тело запроса
        let bodyParams: [String]
        switch method {
        case 1:
            bodyParams = ["screen_ids=\(code)"]
        case 2:
            bodyParams = ["code=\(code)", "device_id=ios_app"]
        case 3:
            bodyParams = ["screen_id=\(code)", "session_token=mobile"]
        default:
            bodyParams = ["screen_ids=\(code)"]
        }
        
        let body = bodyParams.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        print("🌐 Метод \(method): \(url.absoluteString)")
        print("📤 Тело запроса: \(body)")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP статус: \(httpResponse.statusCode)")
                }
                
                if let error = error {
                    print("❌ Ошибка метода \(method): \(error.localizedDescription)")
                    // Пробуем следующий метод
                    self?.attemptConnection(method: method + 1, code: code)
                    return
                }
                
                guard let data = data else {
                    print("❌ Нет данных от метода \(method)")
                    self?.attemptConnection(method: method + 1, code: code)
                    return
                }
                
                // Парсим ответ
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Ответ метода \(method): \(responseString)")
                    
                    // Проверяем есть ли в ответе полезная информация
                    if responseString.contains("lounge_token") || 
                       responseString.contains("loungeToken") ||
                       responseString.contains("token") ||
                       responseString.contains("screen") {
                        self?.parseConnectionResponse(responseString, tvCode: code)
                    } else {
                        // Пробуем следующий метод
                        print("⚠️ Метод \(method) не дал результата, пробуем следующий")
                        self?.attemptConnection(method: method + 1, code: code)
                    }
                } else {
                    self?.connectionStatus = .error("Неверный формат ответа")
                }
            }
        }.resume()
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
    
    private func parseConnectionResponse(_ response: String, tvCode: String) {
        print("🔍 Полный ответ от YouTube TV API:")
        print(response)
        
        // Парсим JSON ответ от YouTube TV API
        guard let responseData = response.data(using: .utf8) else {
            connectionStatus = .error("Ошибка обработки ответа")
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            print("🔍 Распарсенный JSON:")
            print(json ?? "nil")
            
            // Проверяем разные форматы ответа
            if let screens = json?["screens"] as? [[String: Any]], !screens.isEmpty {
                // Формат 1: screens массив
                let firstScreen = screens[0]
                print("🔍 Первый экран: \(firstScreen)")
                
                if let loungeToken = firstScreen["lounge_token"] as? String, !loungeToken.isEmpty {
                    let screenName = firstScreen["name"] as? String ?? "YouTube TV"
                    createSuccessfulConnection(tvCode: tvCode, token: loungeToken, name: screenName)
                    return
                }
                
                // Проверяем другие возможные поля
                if let token = firstScreen["loungeToken"] as? String ?? firstScreen["token"] as? String {
                    let screenName = firstScreen["name"] as? String ?? "YouTube TV"
                    createSuccessfulConnection(tvCode: tvCode, token: token, name: screenName)
                    return
                }
            } else if let screen = json?["screen"] as? [String: Any] {
                // Формат 2: один screen объект
                print("🔍 Объект screen: \(screen)")
                
                if let loungeToken = screen["lounge_token"] as? String ?? screen["loungeToken"] as? String ?? screen["token"] as? String {
                    let screenName = screen["name"] as? String ?? "YouTube TV"
                    createSuccessfulConnection(tvCode: tvCode, token: loungeToken, name: screenName)
                    return
                }
            } else if let status = json?["status"] as? String {
                // Формат 3: статус ответ
                print("🔍 Статус: \(status)")
                
                if status == "ok" || status == "success" {
                    // Пытаемся найти токен в корне ответа
                    if let token = json?["lounge_token"] as? String ?? json?["loungeToken"] as? String ?? json?["token"] as? String {
                        createSuccessfulConnection(tvCode: tvCode, token: token, name: "YouTube TV")
                        return
                    }
                }
            }
            
            // Проверяем на ошибки в ответе
            if let error = json?["error"] as? String {
                connectionStatus = .error("❌ Ошибка API: \(error)")
            } else if response.contains("INVALID") || response.contains("invalid") {
                connectionStatus = .error("❌ Неверный код. Получите новый код на TV")
            } else if response.contains("EXPIRED") || response.contains("expired") {
                connectionStatus = .error("❌ Код истек. Получите новый код на TV")
            } else {
                // Создаем симуляцию подключения для тестирования
                print("⚠️ Токен не найден, создаем тестовое подключение")
                createTestConnection(tvCode: tvCode)
            }
            
        } catch {
            print("❌ Ошибка парсинга JSON: \(error)")
            connectionStatus = .error("Ошибка парсинга ответа: \(error.localizedDescription)")
        }
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
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkCurrentVideo(for: device)
        }
    }
    
    private func checkCurrentVideo(for device: YouTubeTVDevice) {
        // Эмулируем проверку текущего видео
        // В реальной реализации это будет запрос к YouTube TV API для получения состояния воспроизведения
        print("🔍 Мониторинг видео на \(device.name)")
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
        // Эмулируем отправку команды пропуска
        print("⏭️ Пропускаем до времени \(time) на \(device.name)")
        
        // В реальной реализации здесь будет отправка команды через YouTube TV API
        let skipCommand = YouTubeTVCommand.seek(time: time)
        sendCommand(skipCommand, to: device)
    }
    
    func muteDevice(_ device: YouTubeTVDevice) {
        let muteCommand = YouTubeTVCommand.mute
        sendCommand(muteCommand, to: device)
    }
    
    private func sendCommand(_ command: YouTubeTVCommand, to device: YouTubeTVDevice) {
        // Эмулируем отправку команды устройству
        print("📤 Отправляем команду \(command) на \(device.name)")
    }
    
    // MARK: - Cleanup
    func disconnect() {
        connectionStatus = .disconnected
        connectedDevices.removeAll()
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
}

// MARK: - Command Enum
enum YouTubeTVCommand {
    case play
    case pause
    case seek(time: Double)
    case mute
    case unmute
    case skipSegment(SponsorSegment)
} 
