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
        
        // Отправляем SSDP M-SEARCH запрос для поиска YouTube TV устройств
        let ssdpMessage = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            ST: urn:dial-multiscreen-org:service:dial:1\r
            MX: 3\r
            \r
            
            """.data(using: .utf8)!
        
        let connection = NWConnection(
            host: "239.255.255.250",
            port: 1900,
            using: .udp
        )
        
        connection.start(queue: .global())
        connection.send(content: ssdpMessage, completion: .idempotent)
        
        // Слушаем ответы устройств
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                self?.parseSSDP(response: response)
            }
        }
        
        // Останавливаем поиск через 5 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isScanning = false
            connection.cancel()
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
            guard let data = data else { return }
            
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
        
        // Эмулируем процесс связывания с YouTube TV кодом
        // В реальной реализации это будет HTTP запрос к YouTube TV API
        let linkingURL = "https://www.youtube.com/api/lounge/pairing/get_lounge_token_batch"
        var request = URLRequest(url: URL(string: linkingURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "screen_ids=\(code)&client_name=CmdIPhoneApp&device_version=16.0"
        request.httpBody = body.data(using: .utf8)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionStatus = .error("Ошибка связывания: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.connectionStatus = .error("Нет данных от YouTube TV")
                    return
                }
                
                // Парсим ответ с токенами
                if let responseString = String(data: data, encoding: .utf8) {
                    self?.parseConnectionResponse(responseString, tvCode: code)
                }
            }
        }.resume()
    }
    
    private func parseConnectionResponse(_ response: String, tvCode: String) {
        // Простая проверка успешного ответа
        if response.contains("lounge_token") {
            let device = YouTubeTVDevice(
                id: tvCode,
                name: "Samsung Tizen TV (\(tvCode))",
                ipAddress: "Connected",
                port: 0,
                location: "",
                tvCode: tvCode,
                isConnected: true
            )
            
            connectedDevices.append(device)
            connectionStatus = .connected
            
            // Запускаем мониторинг
            startMonitoring(device: device)
        } else {
            connectionStatus = .error("Неверный код TV или устройство недоступно")
        }
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
