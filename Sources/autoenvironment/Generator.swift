import Foundation
import xcodeproj
import PathKit

public class Generator {
    public enum Error: Swift.Error {
        case targetNotFound
        case configurationsNotFound
        case multipleTargetsWithSameName
        case internalFailure
        case writingError
    }

    private let project: XcodeProj
    private let path: Path
    public var encoding: String.Encoding = .utf8

    // MARK: - Lifecycle

    public init(project input: URL) throws {
        path = Path(input.path)
        project = try XcodeProj(path: path)
    }

    // MARK: - Public interface

    public func generateEnvironment(
        for target: String,
        to output: URL,
        enumName: String = "Environment",
        defaultConfig: String? = nil
    ) throws {
        let targets = project.pbxproj.targets(named: target)

        guard let target = targets.first else { throw Error.targetNotFound }
        guard targets.count == 1 else { throw Error.multipleTargetsWithSameName }
        guard let list = target.buildConfigurationList else { throw Error.configurationsNotFound }

        let configurations = list.buildConfigurations.map { $0.name }

        try generateEnvironment(
            for: configurations,
            in: target,
            to: output,
            enumName: enumName,
            defaultConfig: defaultConfig
        )
    }

    public func generateEnvironment(
        for configurations: [String],
        in target: PBXTarget,
        to output: URL,
        enumName: String = "Environment",
        defaultConfig: String? = nil
    ) throws {
        if output.lastPathComponent.hasSuffix(".swift") {
            try generateEnvironment(
                for: configurations,
                in: target,
                directory: output.deletingLastPathComponent(),
                filename: output.lastPathComponent,
                enumName: enumName,
                defaultConfig: defaultConfig
            )
        } else {
            try generateEnvironment(
                for: configurations,
                in: target,
                directory: output,
                filename: "Environment.generated.swift",
                enumName: enumName,
                defaultConfig: defaultConfig
            )
        }
    }

    public func generateEnvironment(
        for configurations: [String],
        in target: PBXTarget,
        directory: URL,
        filename: String,
        enumName: String = "Environment",
        defaultConfig: String? = nil
    ) throws {
        // Prepare
        let cases = configurations.map { name -> String in
            return "\tcase \(name.lowercased()) = \"\(name.uppercased())\""
        }.joined(separator: "\n")

        let current = configurations.enumerated().map { offet, name -> String in
            let statement = offet == 0 ? "#if" : "#elseif"
            return """
            \t\t\(statement) \(name.uppercased())
            \t\treturn .\(name.lowercased())
            """
        }.joined(separator: "\n")

        let defaultEnvironment: String = {
            if let config = defaultConfig?.lowercased() {
                return "\t\treturn .\(config)"
            } else {
                return "\t\t// Add OTHER_SWIFT_FLAGS build settings with flags like -DDEBUG, -DRELEASE"
            }
        }()

        // Generate
        var contents = template
        contents.replace(key: TemplateKey.enumName, with: enumName)
        contents.replace(key: TemplateKey.cases, with: cases)
        contents.replace(key: TemplateKey.current, with: current)
        contents.replace(key: TemplateKey.defaultConfig, with: defaultEnvironment)

        // Write
        guard let data = contents.data(using: encoding) else { throw Error.writingError }
        try data.write(to: directory.appendingPathComponent(filename))
    }

    public func updateCustomSwiftCompilerFlags(
        for target: String,
        to output: URL
    ) throws {
        let targets = project.pbxproj.targets(named: target)

        guard let target = targets.first else { throw Error.targetNotFound }

        // Update project compile flags
        target.buildConfigurationList?.buildConfigurations.forEach { buildConfig in
            let flag = "-D\(buildConfig.name.uppercased())"
            var flags = buildConfig.buildSettings["OTHER_SWIFT_FLAGS"] as? [String] ?? []
            guard !flags.contains(flag) else { return }

            flags.append(flag)
            buildConfig.buildSettings["OTHER_SWIFT_FLAGS"] = flags
        }
        project.pbxproj.add(object: target)

        try project.pbxproj.write(path: XcodeProj.pbxprojPath(path), override: true)
    }

    // MARK: - Helpers
    private enum TemplateKey: String {
        case enumName = "{{ENV_NAME}}"
        case cases = "{{ENV_CASES}}"
        case current = "{{ENV_CURRENT}}"
        case defaultConfig = "{{ENV_DEFAULT}}"
    }

    private let template = """
    // Generated with AutoEnvironment by Andrzej Michnia @GirAppe

    import Foundation

    public enum {{ENV_NAME}}: String {
    {{ENV_CASES}}

        public static var current: Environment {
            if let override = {{ENV_NAME}}Override.current {
                return override
            }

    {{ENV_CURRENT}}
            #else
    {{ENV_DEFAULT}}
            #endif
        }
    }

    public struct {{ENV_NAME}}Override {
        public static var current: {{ENV_NAME}}?
    }
    """
}

private extension String {
    mutating func replace<K: RawRepresentable>(
        key: K,
        with value: String
    ) where K.RawValue == String {
        self = replacingOccurrences(of: key.rawValue, with: value)
    }
}
