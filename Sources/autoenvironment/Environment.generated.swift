// Generated with AutoEnvironment by Andrzej Michnia @GirAppe

import Foundation

private var defaultFormat: Environment.Format = .full
private var formatForEnvironment: [Environment: Environment.Format] = [:]

public enum Environment: String {
	case debug = "DEBUG"
	case release = "RELEASE"

    public static var current: Environment {
        if let override = EnvironmentOverride.current {
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

    public static func setFormat(_ format: Format) {
        defaultFormat = format
    }

    public static func setFormat(_ format: Format, for environment: Environment) {
        formatForEnvironment[environment] = format
    }

    public var formattedInfo: String {
        var value = (formatForEnvironment[self] ?? defaultFormat).string
        value = value.replacingOccurrences(
            of: Format.Key.environment.rawValue,
            with: name)
        value = value.replacingOccurrences(
            of: Format.Key.environmentAbbreviated.rawValue,
            with: abbreviatedName)
        value = value.replacingOccurrences(
            of: Format.Key.version.rawValue,
            with: appVersion)
        value = value.replacingOccurrences(
            of: Format.Key.buildNumber.rawValue,
            with: appBuildNumber)
        return value
    }

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

    public enum Format {
        public enum Key: String {
            case environment = "{{E}}"
            case environmentAbbreviated = "{{AE}}"
            case version = "{{V}}"
            case buildNumber = "{{B}}"
        }

        case simple
        case full
        case just(Key)
        case custom(String)

        public var string: String {
            switch self {
            case .simple: return "v\(Key.version) (\(Key.buildNumber))"
            case .full: return "\(Key.environment) v\(Format.simple.string)"
            case let .just(key): return key.rawValue
            case let .custom(format): return format
            }
        }
    }
}

public struct EnvironmentOverride {
    public static var current: Environment?
}
