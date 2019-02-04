// Generated with AutoEnvironment by Andrzej Michnia @GirAppe

import Foundation

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
}

public struct EnvironmentOverride {
    public static var current: Environment?
}