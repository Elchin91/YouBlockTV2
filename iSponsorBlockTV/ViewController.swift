import UIKit
import Network
import Combine

class ViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    
    // TV Code Input Section
    private let tvCodeHeaderLabel = UILabel()
    private let tvCodeTextField = UITextField()
    private let connectWithCodeButton = UIButton(type: .system)
    private let scanDevicesButton = UIButton(type: .system)
    
    private let devicesHeaderLabel = UILabel()
    private let devicesStackView = UIStackView()
    
    private let settingsHeaderLabel = UILabel()
    private let autoSkipSwitch = UISwitch()
    private let muteAdsSwitch = UISwitch()
    private let skipCategoriesStackView = UIStackView()
    
    private let statisticsHeaderLabel = UILabel()
    private let skippedCountLabel = UILabel()
    private let savedTimeLabel = UILabel()
    private let activeVideoLabel = UILabel()
    
    // MARK: - Properties
    private let youTubeTVManager = YouTubeTVManager.shared
    private var skippedSegments = 0
    private var timeSaved = 0
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupObservers()
        loadSettings()
    }
    
    private func setupObservers() {
        // Наблюдаем за изменениями в YouTubeTVManager
        youTubeTVManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateConnectionStatus(status)
            }
            .store(in: &cancellables)
        
        youTubeTVManager.$connectedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.updateDevicesList(devices)
            }
            .store(in: &cancellables)
        
        youTubeTVManager.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.scanDevicesButton.isEnabled = !isScanning
                self?.scanDevicesButton.setTitle(isScanning ? "Поиск..." : "Сканировать сеть", for: .normal)
            }
            .store(in: &cancellables)
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
        titleLabel.text = "📺 iSponsorBlockTV"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Status
        statusLabel.text = "Не подключено к устройствам"
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemGray
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // TV Code Section
        tvCodeHeaderLabel.text = "Подключение к YouTube TV"
        tvCodeHeaderLabel.font = UIFont.boldSystemFont(ofSize: 20)
        tvCodeHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tvCodeHeaderLabel)
        
        // Instructions label
        let instructionsLabel = UILabel()
        instructionsLabel.text = "1. Откройте YouTube на вашем TV\n2. Перейдите в Настройки → Связать с телефоном\n3. Введите код из настроек ниже:"
        instructionsLabel.font = UIFont.systemFont(ofSize: 14)
        instructionsLabel.textColor = .systemGray
        instructionsLabel.numberOfLines = 0
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionsLabel)
        
        // TV Code input
        tvCodeTextField.placeholder = "Введите код с телевизора (например: ABC-XYZ-123)"
        tvCodeTextField.borderStyle = .roundedRect
        tvCodeTextField.autocapitalizationType = .allCharacters
        tvCodeTextField.font = UIFont.systemFont(ofSize: 18)
        tvCodeTextField.textAlignment = .center
        tvCodeTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tvCodeTextField)
        
        // Connect with code button
        connectWithCodeButton.setTitle("Подключиться к TV", for: .normal)
        connectWithCodeButton.backgroundColor = .systemBlue
        connectWithCodeButton.setTitleColor(.white, for: .normal)
        connectWithCodeButton.layer.cornerRadius = 8
        connectWithCodeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        connectWithCodeButton.addTarget(self, action: #selector(connectWithCodeTapped), for: .touchUpInside)
        connectWithCodeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(connectWithCodeButton)
        
        // Scan devices button
        scanDevicesButton.setTitle("Сканировать сеть", for: .normal)
        scanDevicesButton.backgroundColor = .systemOrange
        scanDevicesButton.setTitleColor(.white, for: .normal)
        scanDevicesButton.layer.cornerRadius = 8
        scanDevicesButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        scanDevicesButton.addTarget(self, action: #selector(scanDevicesTapped), for: .touchUpInside)
        scanDevicesButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scanDevicesButton)
        
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
        settingsHeaderLabel.text = "Настройки блокировки"
        settingsHeaderLabel.font = UIFont.boldSystemFont(ofSize: 20)
        settingsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(settingsHeaderLabel)
        
        // Auto skip setting
        let autoSkipStack = createSettingRow(
            title: "Автоматический пропуск",
            subtitle: "Пропускать спонсорские сегменты автоматически",
            switchControl: autoSkipSwitch
        )
        contentView.addSubview(autoSkipStack)
        
        // Mute ads setting
        let muteAdsStack = createSettingRow(
            title: "Заглушать рекламу",
            subtitle: "Отключать звук во время рекламных роликов",
            switchControl: muteAdsSwitch
        )
        contentView.addSubview(muteAdsStack)
        
        // Skip categories
        let categoriesLabel = UILabel()
        categoriesLabel.text = "Категории для пропуска:"
        categoriesLabel.font = UIFont.systemFont(ofSize: 16)
        categoriesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categoriesLabel)
        
        skipCategoriesStackView.axis = .vertical
        skipCategoriesStackView.spacing = 8
        skipCategoriesStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(skipCategoriesStackView)
        
        // Create category switches
        let categories = [
            ("sponsor", "Спонсорские сегменты"),
            ("intro", "Вступления"),
            ("outro", "Концовки"),
            ("interaction", "Призывы к действию"),
            ("selfpromo", "Саморекламы")
        ]
        
        for (category, title) in categories {
            let categorySwitch = UISwitch()
            categorySwitch.isOn = true
            categorySwitch.tag = categories.firstIndex(where: { $0.0 == category }) ?? 0
            
            let categoryStack = createSettingRow(
                title: title,
                subtitle: "",
                switchControl: categorySwitch
            )
            skipCategoriesStackView.addArrangedSubview(categoryStack)
        }
        
        // Statistics section
        statisticsHeaderLabel.text = "📊 Статистика и активность"
        statisticsHeaderLabel.font = UIFont.boldSystemFont(ofSize: 20)
        statisticsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statisticsHeaderLabel)
        
        activeVideoLabel.text = "Текущее видео: Не воспроизводится"
        activeVideoLabel.font = UIFont.systemFont(ofSize: 14)
        activeVideoLabel.textColor = .systemGray
        activeVideoLabel.numberOfLines = 2
        activeVideoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activeVideoLabel)
        
        skippedCountLabel.text = "Пропущено сегментов: 0"
        skippedCountLabel.font = UIFont.systemFont(ofSize: 16)
        skippedCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(skippedCountLabel)
        
        savedTimeLabel.text = "Сэкономлено времени: 0 мин"
        savedTimeLabel.font = UIFont.systemFont(ofSize: 16)
        savedTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(savedTimeLabel)
        
        // Add switch targets
        autoSkipSwitch.addTarget(self, action: #selector(settingChanged), for: .valueChanged)
        muteAdsSwitch.addTarget(self, action: #selector(settingChanged), for: .valueChanged)
    }
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
        // Находим элементы для расстановки constraints
        let instructionsLabel = contentView.subviews.first { $0 is UILabel && ($0 as! UILabel).text?.contains("Откройте YouTube") == true }!
        let categoriesLabel = contentView.subviews.first { $0 is UILabel && ($0 as! UILabel).text?.contains("Категории") == true }!
        let autoSkipStack = contentView.subviews.first { $0 is UIStackView && $0 != devicesStackView && $0 != skipCategoriesStackView }!
        let muteAdsStack = contentView.subviews.dropFirst().first { $0 is UIStackView && $0 != devicesStackView && $0 != skipCategoriesStackView && $0 != autoSkipStack }!
        
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
            
            // TV Code Header
            tvCodeHeaderLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 30),
            tvCodeHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tvCodeHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Instructions
            instructionsLabel.topAnchor.constraint(equalTo: tvCodeHeaderLabel.bottomAnchor, constant: 12),
            instructionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // TV Code input
            tvCodeTextField.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 16),
            tvCodeTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tvCodeTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tvCodeTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Connect with code button
            connectWithCodeButton.topAnchor.constraint(equalTo: tvCodeTextField.bottomAnchor, constant: 16),
            connectWithCodeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            connectWithCodeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            connectWithCodeButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Scan devices button
            scanDevicesButton.topAnchor.constraint(equalTo: connectWithCodeButton.bottomAnchor, constant: 12),
            scanDevicesButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scanDevicesButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scanDevicesButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Devices header
            devicesHeaderLabel.topAnchor.constraint(equalTo: scanDevicesButton.bottomAnchor, constant: 30),
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
            autoSkipStack.topAnchor.constraint(equalTo: settingsHeaderLabel.bottomAnchor, constant: 16),
            autoSkipStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            autoSkipStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            muteAdsStack.topAnchor.constraint(equalTo: autoSkipStack.bottomAnchor, constant: 16),
            muteAdsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            muteAdsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Categories label
            categoriesLabel.topAnchor.constraint(equalTo: muteAdsStack.bottomAnchor, constant: 20),
            categoriesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoriesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Skip categories stack
            skipCategoriesStackView.topAnchor.constraint(equalTo: categoriesLabel.bottomAnchor, constant: 12),
            skipCategoriesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            skipCategoriesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Statistics header
            statisticsHeaderLabel.topAnchor.constraint(equalTo: skipCategoriesStackView.bottomAnchor, constant: 30),
            statisticsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statisticsHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Statistics labels
            activeVideoLabel.topAnchor.constraint(equalTo: statisticsHeaderLabel.bottomAnchor, constant: 16),
            activeVideoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            activeVideoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            skippedCountLabel.topAnchor.constraint(equalTo: activeVideoLabel.bottomAnchor, constant: 12),
            skippedCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            skippedCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            savedTimeLabel.topAnchor.constraint(equalTo: skippedCountLabel.bottomAnchor, constant: 8),
            savedTimeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            savedTimeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            savedTimeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Actions
    @objc private func connectWithCodeTapped() {
        guard let code = tvCodeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else {
            showAlert(title: "Ошибка", message: "Введите код с телевизора")
            return
        }
        
        // Преобразуем код в правильный формат
        let cleanCode = code.replacingOccurrences(of: "-", with: "").uppercased()
        youTubeTVManager.connectWithTVCode(cleanCode)
        
        // Очищаем поле ввода
        tvCodeTextField.text = ""
        view.endEditing(true)
    }
    
    @objc private func scanDevicesTapped() {
        youTubeTVManager.startDeviceDiscovery()
    }
    
    @objc private func settingChanged() {
        saveSettings()
        updateYouTubeTVSettings()
    }
    
    private func updateYouTubeTVSettings() {
        // Обновляем настройки в YouTubeTVManager
        var settings = YouTubeTVSettings.shared
        settings.autoSkipEnabled = autoSkipSwitch.isOn
        settings.muteAdsEnabled = muteAdsSwitch.isOn
        
        // Собираем выбранные категории
        var selectedCategories: [String] = []
        for (index, categoryInfo) in [
            ("sponsor", "Спонсорские сегменты"),
            ("intro", "Вступления"),
            ("outro", "Концовки"),
            ("interaction", "Призывы к действию"),
            ("selfpromo", "Саморекламы")
        ].enumerated() {
            if let categoryStack = skipCategoriesStackView.arrangedSubviews[safe: index] as? UIStackView,
               let switchControl = categoryStack.arrangedSubviews.last as? UISwitch,
               switchControl.isOn {
                selectedCategories.append(categoryInfo.0)
            }
        }
        settings.skipCategories = selectedCategories
    }
    
    // MARK: - Status Updates
    private func updateConnectionStatus(_ status: YouTubeTVManager.ConnectionStatus) {
        switch status {
        case .disconnected:
            statusLabel.text = "Не подключено к устройствам"
            statusLabel.textColor = .systemGray
            
        case .scanning:
            statusLabel.text = "Поиск устройств в сети..."
            statusLabel.textColor = .systemOrange
            
        case .connecting:
            statusLabel.text = "Подключение к YouTube TV..."
            statusLabel.textColor = .systemBlue
            
        case .connected:
            statusLabel.text = "✅ Подключено к YouTube TV"
            statusLabel.textColor = .systemGreen
            updateStatistics()
            
        case .error(let message):
            statusLabel.text = "❌ Ошибка: \(message)"
            statusLabel.textColor = .systemRed
        }
    }
    
    private func updateStatistics() {
        skippedCountLabel.text = "Пропущено сегментов: \(skippedSegments)"
        
        let minutes = timeSaved / 60
        let hours = minutes / 60
        
        let timeText: String
        if hours > 0 {
            let remainingMinutes = minutes % 60
            timeText = "\(hours)ч \(remainingMinutes)мин"
        } else {
            timeText = "\(minutes) мин"
        }
        
        savedTimeLabel.text = "Сэкономлено времени: \(timeText)"
    }
    
    private func updateDevicesList(_ devices: [YouTubeTVDevice]) {
        // Clear existing device views
        devicesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if devices.isEmpty {
            let noDevicesLabel = UILabel()
            noDevicesLabel.text = "Нет подключенных устройств"
            noDevicesLabel.textColor = .systemGray
            noDevicesLabel.font = UIFont.systemFont(ofSize: 16)
            devicesStackView.addArrangedSubview(noDevicesLabel)
        } else {
            for device in devices {
                let deviceView = createDeviceView(device: device)
                devicesStackView.addArrangedSubview(deviceView)
            }
            
            // Обновляем активное видео если есть подключенные устройства
            if let connectedDevice = devices.first(where: { $0.isConnected }) {
                updateActiveVideo(for: connectedDevice)
            }
        }
    }
    
    private func updateActiveVideo(for device: YouTubeTVDevice) {
        // Эмулируем получение информации о текущем видео
        youTubeTVManager.checkSponsorSegments(videoId: "dQw4w9WgXcQ") { [weak self] segments in
            if segments.isEmpty {
                self?.activeVideoLabel.text = "Текущее видео: Нет спонсорских сегментов"
            } else {
                self?.activeVideoLabel.text = "Текущее видео: Найдено \(segments.count) сегментов для пропуска"
            }
        }
    }
    
    private func createDeviceView(device: YouTubeTVDevice) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemGray6
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = device.name
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let modelLabel = UILabel()
        modelLabel.text = device.model ?? "YouTube TV"
        modelLabel.font = UIFont.systemFont(ofSize: 14)
        modelLabel.textColor = .systemGray
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusIndicator = UIView()
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.backgroundColor = device.isConnected ? .systemGreen : .systemGray
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let statusLabel = UILabel()
        statusLabel.text = device.isConnected ? "Подключено" : "Не подключено"
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = device.isConnected ? .systemGreen : .systemGray
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let ipLabel = UILabel()
        ipLabel.text = device.ipAddress
        ipLabel.font = UIFont.systemFont(ofSize: 12)
        ipLabel.textColor = .systemGray2
        ipLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(nameLabel)
        containerView.addSubview(modelLabel)
        containerView.addSubview(statusIndicator)
        containerView.addSubview(statusLabel)
        containerView.addSubview(ipLabel)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 90),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: statusIndicator.leadingAnchor, constant: -8),
            
            modelLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            modelLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            modelLabel.trailingAnchor.constraint(equalTo: statusIndicator.leadingAnchor, constant: -8),
            
            ipLabel.topAnchor.constraint(equalTo: modelLabel.bottomAnchor, constant: 4),
            ipLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            ipLabel.trailingAnchor.constraint(equalTo: statusIndicator.leadingAnchor, constant: -8),
            
            statusIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -10),
            statusIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            statusLabel.topAnchor.constraint(equalTo: statusIndicator.bottomAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        return containerView
    }
    
    // MARK: - Settings
    private func loadSettings() {
        let defaults = UserDefaults.standard
        autoSkipSwitch.isOn = defaults.bool(forKey: "autoSkipEnabled")
        muteAdsSwitch.isOn = defaults.bool(forKey: "muteAdsEnabled")
        
        // Загружаем выбранные категории
        let savedCategories = defaults.stringArray(forKey: "skipCategories") ?? ["sponsor", "intro", "outro", "interaction", "selfpromo"]
        
        for (index, categoryInfo) in [
            ("sponsor", "Спонсорские сегменты"),
            ("intro", "Вступления"),
            ("outro", "Концовки"),
            ("interaction", "Призывы к действию"),
            ("selfpromo", "Саморекламы")
        ].enumerated() {
            if let categoryStack = skipCategoriesStackView.arrangedSubviews[safe: index] as? UIStackView,
               let switchControl = categoryStack.arrangedSubviews.last as? UISwitch {
                switchControl.isOn = savedCategories.contains(categoryInfo.0)
            }
        }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoSkipSwitch.isOn, forKey: "autoSkipEnabled")
        defaults.set(muteAdsSwitch.isOn, forKey: "muteAdsEnabled")
        
        // Сохраняем выбранные категории
        var selectedCategories: [String] = []
        for (index, categoryInfo) in [
            ("sponsor", "Спонсорские сегменты"),
            ("intro", "Вступления"),
            ("outro", "Концовки"),
            ("interaction", "Призывы к действию"),
            ("selfpromo", "Саморекламы")
        ].enumerated() {
            if let categoryStack = skipCategoriesStackView.arrangedSubviews[safe: index] as? UIStackView,
               let switchControl = categoryStack.arrangedSubviews.last as? UISwitch,
               switchControl.isOn {
                selectedCategories.append(categoryInfo.0)
            }
        }
        defaults.set(selectedCategories, forKey: "skipCategories")
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 