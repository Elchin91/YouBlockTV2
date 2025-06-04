import Foundation

// MARK: - YouTube TV настройки
class YouTubeTVSettings: ObservableObject {
    static let shared = YouTubeTVSettings()
    private init() {}
    
    @Published var autoSkipEnabled = true
    @Published var muteAdsEnabled = false
    @Published var skipCategories: [String] = ["sponsor", "intro", "outro", "interaction", "selfpromo"]
    
    // Настройки агрессивности блокировки
    @Published var skipThreshold: TimeInterval = 1.0  // Минимальная длительность сегмента для пропуска
    @Published var enabledForChannels: [String] = []  // Список каналов где включена блокировка
    @Published var disabledForChannels: [String] = [] // Список каналов где отключена блокировка
    
    // Статистика
    @Published var totalSegmentsSkipped = 0
    @Published var totalTimeSaved: TimeInterval = 0
    
    // Методы для обновления статистики
    func recordSkippedSegment(duration: TimeInterval, category: String) {
        totalSegmentsSkipped += 1
        totalTimeSaved += duration
        
        // Сохраняем в UserDefaults
        UserDefaults.standard.set(totalSegmentsSkipped, forKey: "totalSegmentsSkipped")
        UserDefaults.standard.set(totalTimeSaved, forKey: "totalTimeSaved")
    }
    
    // Загрузка настроек из UserDefaults
    func loadSettings() {
        let defaults = UserDefaults.standard
        autoSkipEnabled = defaults.bool(forKey: "autoSkipEnabled")
        muteAdsEnabled = defaults.bool(forKey: "muteAdsEnabled")
        skipCategories = defaults.stringArray(forKey: "skipCategories") ?? ["sponsor", "intro", "outro", "interaction", "selfpromo"]
        skipThreshold = defaults.double(forKey: "skipThreshold") > 0 ? defaults.double(forKey: "skipThreshold") : 1.0
        
        totalSegmentsSkipped = defaults.integer(forKey: "totalSegmentsSkipped")
        totalTimeSaved = defaults.double(forKey: "totalTimeSaved")
    }
    
    // Сохранение настроек в UserDefaults
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoSkipEnabled, forKey: "autoSkipEnabled")
        defaults.set(muteAdsEnabled, forKey: "muteAdsEnabled")
        defaults.set(skipCategories, forKey: "skipCategories")
        defaults.set(skipThreshold, forKey: "skipThreshold")
    }
    
    // Проверка, нужно ли пропускать категорию
    func shouldSkipCategory(_ category: String) -> Bool {
        return skipCategories.contains(category)
    }
    
    // Форматированное время
    var formattedTimeSaved: String {
        let hours = Int(totalTimeSaved) / 3600
        let minutes = (Int(totalTimeSaved) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)ч \(minutes)мин"
        } else if minutes > 0 {
            return "\(minutes) мин"
        } else {
            return "\(Int(totalTimeSaved)) сек"
        }
    }
}

// MARK: - SponsorBlock API модели
struct SponsorSegment: Codable {
    let segment: [Double]      // [startTime, endTime]
    let category: String       // "sponsor", "intro", "outro", etc.
    let actionType: String     // "skip", "mute", "poi"
    let description: String?
    let locked: Int?
    let votes: Int?
    let videoID: String?
    let UUID: String?
    
    var startTime: Double { segment[0] }
    var endTime: Double { segment[1] }
    var duration: Double { endTime - startTime }
}

struct SponsorBlockResponse: Codable {
    let segments: [SponsorSegment]
}

// MARK: - YouTube TV API модели 
struct YouTubeTVDevice: Codable, Identifiable {
    let id: String
    let name: String
    let model: String?
    let ipAddress: String
    let port: Int
    let location: String
    var tvCode: String?
    var isConnected: Bool = false
    let capabilities: [String]
    
    init(id: String, name: String, model: String? = nil, ipAddress: String, port: Int = 8080, location: String = "", tvCode: String? = nil, isConnected: Bool = false, capabilities: [String] = []) {
        self.id = id
        self.name = name
        self.model = model
        self.ipAddress = ipAddress
        self.port = port
        self.location = location
        self.tvCode = tvCode
        self.isConnected = isConnected
        self.capabilities = capabilities
    }
    
    var emoji: String {
        switch name.lowercased() {
        case let name where name.contains("samsung"):
            return "📺"
        case let name where name.contains("apple"):
            return "📱"
        case let name where name.contains("chromecast"):
            return "📡"
        default:
            return "📺"
        }
    }
}

struct VideoInfo: Codable {
    let videoId: String
    let title: String
    let channelName: String
    let duration: TimeInterval
    let currentTime: TimeInterval
    let isPlaying: Bool
} 