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
        #endif
        // If missing return - add swift compiler flags like -DRELEASE etc.
    }
}

public struct EnvironmentOverride {
    public static var current: Environment?
}
