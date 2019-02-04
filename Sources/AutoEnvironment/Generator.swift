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
    public var encoding: String.Encoding = .utf8

    // MARK: - Lifecycle

    public init(project input: URL) throws {
        project = try XcodeProj(path: Path(input.path))
    }

    // MARK: - Public interface

    public func generateEnvironment(
        for target: String,
        to output: URL,
        enumName: String = "Environment"
    ) throws {
        let targets = project.pbxproj.targets(named: target)

        guard let target = targets.first else { throw Error.targetNotFound }
        guard targets.count == 1 else { throw Error.multipleTargetsWithSameName }
        guard let list = target.buildConfigurationList else { throw Error.configurationsNotFound }

        let configurations = list.buildConfigurations.map { $0.name }

        try generateEnvironment(
            for: configurations,
            to: output,
            enumName: enumName
        )
    }

    public func generateEnvironment(
        for configurations: [String],
        to output: URL,
        enumName: String = "Environment"
    ) throws {
        if output.lastPathComponent.hasSuffix(".swift") {
            try generateEnvironment(
                for: configurations,
                directory: output.deletingLastPathComponent(),
                filename: output.lastPathComponent,
                enumName: enumName
            )
        } else {
            try generateEnvironment(
                for: configurations,
                directory: output,
                filename: "Environment.generated.swift",
                enumName: enumName
            )
        }
    }

    public func generateEnvironment(
        for configurations: [String],
        directory: URL,
        filename: String,
        enumName: String = "Environment"
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

        // Generate
        var contents = template
        contents.replace(key: TemplateKey.enumName, with: enumName)
        contents.replace(key: TemplateKey.cases, with: cases)
        contents.replace(key: TemplateKey.current, with: current)

        // Write
        guard let data = contents.data(using: encoding) else { throw Error.writingError }
        try data.write(to: directory.appendingPathComponent(filename))

        // Update project compile flags
    }

    // MARK: - Helpers
    private enum TemplateKey: String {
        case enumName = "{{ENV_NAME}}"
        case cases = "{{ENV_CASES}}"
        case current = "{{ENV_CURRENT}}"
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
            #endif
            // If missing return - add swift compiler flags like -DRELEASE etc.
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
