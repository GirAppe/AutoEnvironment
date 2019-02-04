// Generated with AutoEnvironment 0.1.1 by Andrzej Michnia @GirAppe

import Foundation
#if os(iOS)
import UIKit
#endif

/// Abstraction for build configuration/environment
public enum Environment: String {
	case debug = "DEBUG"
	case release = "RELEASE"

    public static var current: Environment {
        if let override = Environment.Override.current {
            return override
        }

		#if DEBUG
		return .debug
		#elseif RELEASE
		return .release
        #else
		return .release
        #endif
    }

    public struct Override {
        public static var current: Environment?
    }
}

// MARK: - Formatting info

public extension Environment {

    public var formattedInfo: String {
        var value = (formatForEnvironment[self] ?? defaultFormat).string
        value = value.replacingOccurrences(
            of: Format.Key.environment.rawValue,
            with: name)
        value = value.replacingOccurrences(
            of: Format.Key.environmentAbbreviated.rawValue,
            with: abbreviatedName)
        value = value.replacingOccurrences(
            of: Format.Key.versionNumber.rawValue,
            with: appVersion)
        value = value.replacingOccurrences(
            of: Format.Key.buildNumber.rawValue,
            with: appBuildNumber)
        return value
    }

    public static func setVersionFormat(_ format: Format) {
        defaultFormat = format
    }

    public static func setVersionFormat(_ format: Format, for environment: Environment) {
        formatForEnvironment[environment] = format
    }

    public enum Format {
        public enum Key: String {
            case environment
            case environmentAbbreviated
            case versionNumber
            case buildNumber
        }

        case none
        case simple
        case full
        case just(Key)
        case custom(String)

        public var string: String {
            switch self {
            case .none: return ""
            case .simple: return "v\(Key.versionNumber) (\(Key.buildNumber))"
            case .full: return "\(Key.environment) v\(Format.simple.string)"
            case let .just(key): return key.rawValue
            case let .custom(format): return format
            }
        }
    }
}

// MARK: - Utils

public extension Environment {

    public var name: String {
        return rawValue.capitalized
    }

    public var abbreviatedName: String {
        return String(name.first!).capitalized
    }

    public var appVersion: String {
        guard let infoDictionary = Bundle.main.infoDictionary else { return "unknown" }
        return infoDictionary["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    public var appBuildNumber: String {
        guard let infoDictionary = Bundle.main.infoDictionary else { return "unknown" }
        return infoDictionary["CFBundleVersion"] as? String ?? "unknown"
    }
}

#if os(iOS)
public extension Environment {
    /// Info container - allows showing environment/configuration version information on top of everything
    public static var info = Info()

    public class Info {
        public var isHidden: Bool = true {
            didSet { update() }
        }
        public var textAlignment: NSTextAlignment = .left {
            didSet { update() }
        }
        public var textColor: UIColor = .lightGray {
            didSet { update() }
        }
        public var shadowColor: UIColor = .darkGray {
            didSet { update() }
        }

        public func showVersion() {
            setupWindowIfNeeded()
            uiwindow?.isHidden = false
        }

        public func hideVersion() {
            uiwindow?.isHidden = true
        }

        private var uiwindow: UIWindow?
        private weak var label: UILabel?

        fileprivate init() {}

        private func setupWindowIfNeeded() {
            guard uiwindow == nil else { return }

            let window = UIWindow(frame: UIScreen.main.bounds)
            window.backgroundColor = .clear
            window.windowLevel = UIWindow.Level.alert + 1
            window.isUserInteractionEnabled = false

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 8)
            label.text = Environment.current.formattedInfo
            label.textAlignment = textAlignment
            label.textColor = textColor
            label.shadowColor = shadowColor

            let dummy = UIViewController()
            dummy.view.backgroundColor = UIColor.clear
            window.rootViewController = dummy
            dummy.view.addSubview(label)
            label.rightAnchor.constraint(equalTo: dummy.view.rightAnchor, constant: 2).isActive = true
            label.leftAnchor.constraint(equalTo: dummy.view.leftAnchor, constant: 2).isActive = true
            label.bottomAnchor.constraint(equalTo: dummy.view.bottomAnchor, constant: 2).isActive = true
            label.heightAnchor.constraint(equalToConstant: 12).isActive = true
            dummy.view.bringSubviewToFront(label)

            self.uiwindow = window
            self.label = label
        }

        private func update() {
            label?.text = Environment.current.formattedInfo
            label?.textAlignment = textAlignment
            label?.textColor = textColor
            label?.shadowColor = shadowColor
            isHidden ? hideVersion() : showVersion()
        }
    }
}
#endif

// MARK: - Private

private var defaultFormat: Environment.Format = .full
private var formatForEnvironment: [Environment: Environment.Format] = [:]