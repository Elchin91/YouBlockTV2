#!/bin/bash

# Скрипт для создания базового Xcode проекта iSponsorBlockTV
# Создан для использования в GitHub Actions

echo "Создание базового Xcode проекта..."

# Создаем структуру папок
mkdir -p iSponsorBlockTV
mkdir -p iSponsorBlockTV/Base.lproj
mkdir -p iSponsorBlockTV/Assets.xcassets/AppIcon.appiconset
mkdir -p iSponsorBlockTV/Assets.xcassets/AccentColor.colorset

# Создаем исходные файлы Swift
cat > iSponsorBlockTV/AppDelegate.swift << 'EOF'
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}
EOF

# Создаем NetworkManager.swift если его еще нет
if [ ! -f "iSponsorBlockTV/NetworkManager.swift" ]; then
cat > iSponsorBlockTV/NetworkManager.swift << 'EOF'
import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    private let session = URLSession.shared
    private var baseURL: String = ""
    
    // MARK: - Connection
    func setBaseURL(_ url: String) {
        baseURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
            baseURL = "http://" + baseURL
        }
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
    }
    
    func checkConnection(completion: @escaping (Bool) -> Void) {
        guard !baseURL.isEmpty else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/status") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Device Management
    func getConnectedDevices(completion: @escaping ([Device]) -> Void) {
        guard let url = URL(string: "\(baseURL)/devices") else {
            completion([])
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let devices = try? JSONDecoder().decode([Device].self, from: data) else {
                    // Возвращаем симулированные данные если API недоступно
                    completion(self.simulatedDevices())
                    return
                }
                completion(devices)
            }
        }.resume()
    }
    
    private func simulatedDevices() -> [Device] {
        return [
            Device(id: "1", name: "Apple TV (Гостиная)", type: "apple_tv", status: "connected"),
            Device(id: "2", name: "Samsung TV (Спальня)", type: "samsung_tv", status: "connected"),
            Device(id: "3", name: "Chromecast (Кухня)", type: "chromecast", status: "connected")
        ]
    }
    
    // MARK: - Settings
    func getSettings(completion: @escaping (ServerSettings?) -> Void) {
        guard let url = URL(string: "\(baseURL)/settings") else {
            completion(nil)
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let settings = try? JSONDecoder().decode(ServerSettings.self, from: data) else {
                    completion(nil)
                    return
                }
                completion(settings)
            }
        }.resume()
    }
    
    func updateSettings(_ settings: ServerSettings, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/settings") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(settings)
        } catch {
            completion(false)
            return
        }
        
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Statistics
    func getStatistics(completion: @escaping (Statistics?) -> Void) {
        guard let url = URL(string: "\(baseURL)/stats") else {
            completion(nil)
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let stats = try? JSONDecoder().decode(Statistics.self, from: data) else {
                    // Возвращаем симулированные данные
                    completion(Statistics(segmentsSkipped: 127, timeSaved: 2547))
                    return
                }
                completion(stats)
            }
        }.resume()
    }
}

// MARK: - Data Models
struct Device: Codable {
    let id: String
    let name: String
    let type: String
    let status: String
    
    var emoji: String {
        switch type {
        case "apple_tv":
            return "📺"
        case "samsung_tv", "lg_tv":
            return "📺"
        case "chromecast":
            return "📱"
        case "roku":
            return "📺"
        case "fire_tv":
            return "🔥"
        default:
            return "📺"
        }
    }
    
    var isConnected: Bool {
        return status == "connected"
    }
}

struct ServerSettings: Codable {
    var sponsorBlockEnabled: Bool
    var adBlockEnabled: Bool
    var autoSkipEnabled: Bool
    var skipCategories: [String]
    
    init(sponsorBlockEnabled: Bool = true, 
         adBlockEnabled: Bool = false, 
         autoSkipEnabled: Bool = true,
         skipCategories: [String] = ["sponsor", "intro", "outro"]) {
        self.sponsorBlockEnabled = sponsorBlockEnabled
        self.adBlockEnabled = adBlockEnabled
        self.autoSkipEnabled = autoSkipEnabled
        self.skipCategories = skipCategories
    }
}

struct Statistics: Codable {
    let segmentsSkipped: Int
    let timeSaved: Int // в секундах
    
    var formattedTimeSaved: String {
        let minutes = timeSaved / 60
        let hours = minutes / 60
        
        if hours > 0 {
            let remainingMinutes = minutes % 60
            return "\(hours)ч \(remainingMinutes)мин"
        } else {
            return "\(minutes) мин"
        }
    }
}
EOF
fi

cat > iSponsorBlockTV/ViewController.swift << 'EOF'
import UIKit
import Network

class ViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let serverAddressTextField = UITextField()
    private let connectButton = UIButton(type: .system)
    
    private let devicesHeaderLabel = UILabel()
    private let devicesStackView = UIStackView()
    
    private let settingsHeaderLabel = UILabel()
    private let sponsorBlockEnabledSwitch = UISwitch()
    private let adBlockEnabledSwitch = UISwitch()
    private let autoSkipSwitch = UISwitch()
    
    private let statisticsHeaderLabel = UILabel()
    private let skippedCountLabel = UILabel()
    private let savedTimeLabel = UILabel()
    
    // MARK: - Properties
    private var isConnected = false
    private var serverAddress = "http://192.168.1.100:8000"
    private var connectedDevices: [Device] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadSettings()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "iSponsorBlockTV"
        
        // Scroll view setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = "iSponsorBlockTV Client"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Status
        statusLabel.text = "Отключено от сервера"
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemRed
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Server address input
        serverAddressTextField.placeholder = "Адрес сервера (http://192.168.1.100:8000)"
        serverAddressTextField.text = serverAddress
        serverAddressTextField.borderStyle = .roundedRect
        serverAddressTextField.autocapitalizationType = .none
        serverAddressTextField.keyboardType = .URL
        serverAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(serverAddressTextField)
        
        // Connect button
        connectButton.setTitle("Подключиться", for: .normal)
        connectButton.backgroundColor = .systemBlue
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 8
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(connectButton)
        
        // Devices section
        devicesHeaderLabel.text = "Подключенные устройства"
        devicesHeaderLabel.font = UIFont.boldSystemFont(ofSize: 20)
        devicesHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(devicesHeaderLabel)
        
        devicesStackView.axis = .vertical
        devicesStackView.spacing = 8
        devicesStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(devicesStackView)
        
        // Settings section
        settingsHeaderLabel.text = "Настройки"
        settingsHeaderLabel.font = UIFont.boldSystemFont(ofSize: 20)
        settingsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(settingsHeaderLabel)
        
        // SponsorBlock setting
        let sponsorBlockStack = createSettingRow(
            title: "Блокировка спонсоров",
            subtitle: "Автоматически пропускать спонсорские сегменты",
            switchControl: sponsorBlockEnabledSwitch
        )
        contentView.addSubview(sponsorBlockStack)
        
        // Ad block setting
        let adBlockStack = createSettingRow(
            title: "Блокировка рекламы",
            subtitle: "Пропускать рекламные ролики YouTube",
            switchControl: adBlockEnabledSwitch
        )
        contentView.addSubview(adBlockStack)
        
        // Auto skip setting
        let autoSkipStack = createSettingRow(
            title: "Автопропуск",
            subtitle: "Автоматически пропускать без подтверждения",
            switchControl: autoSkipSwitch
        )
        contentView.addSubview(autoSkipStack)
        
        // Statistics section
        statisticsHeaderLabel.text = "Статистика"
        statisticsHeaderLabel.font = UIFont.boldSystemFont(ofSize: 20)
        statisticsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statisticsHeaderLabel)
        
        skippedCountLabel.text = "Пропущено сегментов: 0"
        skippedCountLabel.font = UIFont.systemFont(ofSize: 16)
        skippedCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(skippedCountLabel)
        
        savedTimeLabel.text = "Сэкономлено времени: 0 мин"
        savedTimeLabel.font = UIFont.systemFont(ofSize: 16)
        savedTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(savedTimeLabel)
        
        // Add switch targets
        sponsorBlockEnabledSwitch.addTarget(self, action: #selector(settingChanged), for: .valueChanged)
        adBlockEnabledSwitch.addTarget(self, action: #selector(settingChanged), for: .valueChanged)
        autoSkipSwitch.addTarget(self, action: #selector(settingChanged), for: .valueChanged)
        
        updateDevicesList()
    }
    
    private func createSettingRow(title: String, subtitle: String, switchControl: UISwitch) -> UIStackView {
        let mainStack = UIStackView()
        mainStack.axis = .horizontal
        mainStack.alignment = .center
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        let labelsStack = UIStackView()
        labelsStack.axis = .vertical
        labelsStack.spacing = 4
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.numberOfLines = 0
        
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(subtitleLabel)
        
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        
        mainStack.addArrangedSubview(labelsStack)
        mainStack.addArrangedSubview(switchControl)
        
        return mainStack
    }
    
    private func setupConstraints() {
        let sponsorBlockStack = contentView.subviews.first { $0 is UIStackView && $0 != devicesStackView }!
        let adBlockStack = contentView.subviews.dropFirst().first { $0 is UIStackView && $0 != devicesStackView && $0 != sponsorBlockStack }!
        let autoSkipStack = contentView.subviews.dropFirst(2).first { $0 is UIStackView && $0 != devicesStackView && $0 != sponsorBlockStack && $0 != adBlockStack }!
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Status
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Server address
            serverAddressTextField.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            serverAddressTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            serverAddressTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            serverAddressTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Connect button
            connectButton.topAnchor.constraint(equalTo: serverAddressTextField.bottomAnchor, constant: 16),
            connectButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            connectButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Devices header
            devicesHeaderLabel.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 30),
            devicesHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            devicesHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Devices stack
            devicesStackView.topAnchor.constraint(equalTo: devicesHeaderLabel.bottomAnchor, constant: 16),
            devicesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            devicesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Settings header
            settingsHeaderLabel.topAnchor.constraint(equalTo: devicesStackView.bottomAnchor, constant: 30),
            settingsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            settingsHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Settings stacks
            sponsorBlockStack.topAnchor.constraint(equalTo: settingsHeaderLabel.bottomAnchor, constant: 16),
            sponsorBlockStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sponsorBlockStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            adBlockStack.topAnchor.constraint(equalTo: sponsorBlockStack.bottomAnchor, constant: 16),
            adBlockStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            adBlockStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            autoSkipStack.topAnchor.constraint(equalTo: adBlockStack.bottomAnchor, constant: 16),
            autoSkipStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            autoSkipStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Statistics header
            statisticsHeaderLabel.topAnchor.constraint(equalTo: autoSkipStack.bottomAnchor, constant: 30),
            statisticsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statisticsHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Statistics labels
            skippedCountLabel.topAnchor.constraint(equalTo: statisticsHeaderLabel.bottomAnchor, constant: 16),
            skippedCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            skippedCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            savedTimeLabel.topAnchor.constraint(equalTo: skippedCountLabel.bottomAnchor, constant: 8),
            savedTimeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            savedTimeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            savedTimeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Actions
    @objc private func connectButtonTapped() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    @objc private func settingChanged() {
        saveSettings()
        // Here you would send settings to the server
        if isConnected {
            sendSettingsToServer()
        }
    }
    
    // MARK: - Connection Logic
    private func connect() {
        guard let address = serverAddressTextField.text, !address.isEmpty else {
            showAlert(title: "Ошибка", message: "Введите адрес сервера")
            return
        }
        
        serverAddress = address
        NetworkManager.shared.setBaseURL(serverAddress)
        
        NetworkManager.shared.checkConnection { [weak self] success in
            if success {
                self?.isConnected = true
                self?.updateConnectionStatus()
                self?.loadDevicesAndStats()
            } else {
                self?.showAlert(title: "Ошибка", message: "Не удается подключиться к серверу")
            }
        }
    }
    
    private func disconnect() {
        isConnected = false
        updateConnectionStatus()
        connectedDevices.removeAll()
        updateDevicesList()
    }
    
    private func loadDevicesAndStats() {
        NetworkManager.shared.getConnectedDevices { [weak self] devices in
            self?.connectedDevices = devices
            self?.updateDevicesList()
        }
        
        NetworkManager.shared.getStatistics { [weak self] stats in
            if let stats = stats {
                self?.skippedCountLabel.text = "Пропущено сегментов: \(stats.segmentsSkipped)"
                self?.savedTimeLabel.text = "Сэкономлено времени: \(stats.formattedTimeSaved)"
            }
        }
    }
    
    private func updateConnectionStatus() {
        if isConnected {
            statusLabel.text = "Подключено к серверу"
            statusLabel.textColor = .systemGreen
            connectButton.setTitle("Отключиться", for: .normal)
            connectButton.backgroundColor = .systemRed
        } else {
            statusLabel.text = "Отключено от сервера"
            statusLabel.textColor = .systemRed
            connectButton.setTitle("Подключиться", for: .normal)
            connectButton.backgroundColor = .systemBlue
        }
    }
    
    private func updateDevicesList() {
        // Clear existing device views
        devicesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if connectedDevices.isEmpty {
            let noDevicesLabel = UILabel()
            noDevicesLabel.text = "Нет подключенных устройств"
            noDevicesLabel.textColor = .systemGray
            noDevicesLabel.font = UIFont.systemFont(ofSize: 16)
            devicesStackView.addArrangedSubview(noDevicesLabel)
        } else {
            for device in connectedDevices {
                let deviceView = createDeviceView(device: device)
                devicesStackView.addArrangedSubview(deviceView)
            }
        }
    }
    
    private func createDeviceView(device: Device) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = device.emoji
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        
        let nameLabel = UILabel()
        nameLabel.text = device.name
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        let statusIndicator = UIView()
        statusIndicator.backgroundColor = device.isConnected ? .systemGreen : .systemGray
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(UIView()) // Spacer
        stackView.addArrangedSubview(statusIndicator)
        
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        return containerView
    }
    
    // MARK: - Settings
    private func loadSettings() {
        let defaults = UserDefaults.standard
        sponsorBlockEnabledSwitch.isOn = defaults.bool(forKey: "sponsorBlockEnabled")
        adBlockEnabledSwitch.isOn = defaults.bool(forKey: "adBlockEnabled")
        autoSkipSwitch.isOn = defaults.bool(forKey: "autoSkipEnabled")
        serverAddress = defaults.string(forKey: "serverAddress") ?? "http://192.168.1.100:8000"
        serverAddressTextField.text = serverAddress
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(sponsorBlockEnabledSwitch.isOn, forKey: "sponsorBlockEnabled")
        defaults.set(adBlockEnabledSwitch.isOn, forKey: "adBlockEnabled")
        defaults.set(autoSkipSwitch.isOn, forKey: "autoSkipEnabled")
        defaults.set(serverAddress, forKey: "serverAddress")
    }
    
    private func sendSettingsToServer() {
        let settings = ServerSettings(
            sponsorBlockEnabled: sponsorBlockEnabledSwitch.isOn,
            adBlockEnabled: adBlockEnabledSwitch.isOn,
            autoSkipEnabled: autoSkipSwitch.isOn
        )
        
        NetworkManager.shared.updateSettings(settings) { success in
            if !success {
                print("Не удалось обновить настройки на сервере")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
EOF

# Создаем storyboard файлы
cat > iSponsorBlockTV/Base.lproj/Main.storyboard << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21701" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="BYZ-38-t0r">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21679"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="System colors in document" minToolsVersion="11.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="tne-QT-ifu">
            <objects>
                <viewController id="BYZ-38-t0r" customClass="ViewController" customModule="iSponsorBlockTV" customModuleProvider="target" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="8bC-Xf-vdC">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" systemColor="systemBackgroundColor"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="dkx-z0-nzr" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="132" y="4"/>
        </scene>
    </scenes>
    <resources>
        <systemColor name="systemBackgroundColor">
            <color white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
        </systemColor>
    </resources>
</document>
EOF

cat > iSponsorBlockTV/Base.lproj/LaunchScreen.storyboard << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21701" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21679"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="System colors in document" minToolsVersion="11.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" systemColor="systemBackgroundColor"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <systemColor name="systemBackgroundColor">
            <color white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
        </systemColor>
    </resources>
</document>
EOF

# Создаем Assets.xcassets
cat > iSponsorBlockTV/Assets.xcassets/Contents.json << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > iSponsorBlockTV/Assets.xcassets/AppIcon.appiconset/Contents.json << 'EOF'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > iSponsorBlockTV/Assets.xcassets/AccentColor.colorset/Contents.json << 'EOF'
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Устанавливаем xcodegen если его нет
if ! command -v xcodegen &> /dev/null; then
    echo "Устанавливаем xcodegen..."
    brew install xcodegen
fi

# Создаем project.yml для xcodegen
cat > project.yml << 'EOF'
name: iSponsorBlockTV
options:
  bundleIdPrefix: com.elchin91
  deploymentTarget:
    iOS: 14.0
configs:
  Debug: debug
  Release: release
targets:
  iSponsorBlockTV:
    type: application
    platform: iOS
    sources:
      - iSponsorBlockTV
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.elchin91.isponsorblockTV
        PRODUCT_NAME: iSponsorBlockTV
        CODE_SIGN_STYLE: Manual
        CODE_SIGNING_REQUIRED: NO
        CODE_SIGNING_ALLOWED: NO
        CODE_SIGN_IDENTITY: ""
        DEVELOPMENT_TEAM: ""
        PROVISIONING_PROFILE_SPECIFIER: ""
        INFOPLIST_FILE: iSponsorBlockTV/Info.plist
        MARKETING_VERSION: 1.0
        CURRENT_PROJECT_VERSION: 1
        TARGETED_DEVICE_FAMILY: "1,2"
        SWIFT_VERSION: 5.0
        ENABLE_BITCODE: NO
        VALID_ARCHS: "arm64"
        ARCHS: "arm64"
        ONLY_ACTIVE_ARCH: NO
        EXCLUDED_ARCHS[sdk=iphonesimulator*]: "arm64"
        STRIP_SWIFT_SYMBOLS: NO
        COPY_PHASE_STRIP: NO
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: YES
      configs:
        Debug:
          SWIFT_OPTIMIZATION_LEVEL: "-Onone"
          SWIFT_COMPILATION_MODE: "incremental"
          COPY_PHASE_STRIP: NO
        Release:
          SWIFT_OPTIMIZATION_LEVEL: "-O"
          SWIFT_COMPILATION_MODE: "wholemodule"
          COPY_PHASE_STRIP: YES
schemes:
  iSponsorBlockTV:
    build:
      targets:
        iSponsorBlockTV: all
    run:
      config: Debug
    archive:
      config: Release
EOF

# Генерируем проект с помощью xcodegen
echo "Генерируем Xcode проект..."
xcodegen generate

# Делаем скрипт исполняемым
chmod +x create_project.sh

echo "Базовый Xcode проект создан успешно!" 