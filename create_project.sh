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

# Пропускаем создание NetworkManager.swift - используем YouTubeTVManager
if false; then
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

# Пропускаем создание ViewController.swift - используем существующий
# (Файл уже создан с правильной версией)
if false; then
echo "Создание ViewController пропущено - используем существующий файл"
EOF
fi

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
