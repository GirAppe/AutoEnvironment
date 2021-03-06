import Foundation
import xcodeproj
import PathKit
import Crayon

private extension String {
    var sanitized: String {
        return self.replacingOccurrences(of: "-", with: "_")
    }
}

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
        if input.path.hasSuffix("/") {
            path = Path(String(input.path.dropLast()))
        } else {
            path = Path(input.path)
        }
        project = try XcodeProj(path: path)
    }

    // MARK: - Public interface

    public func generateEnvironment(
        for target: String?,
        to output: URL,
        enumName: String = "Environment",
        defaultConfig: String? = nil
    ) throws {
        let targetName = target ?? path.lastComponent.replacingOccurrences(of: ".xcodeproj", with: "")
        print("Looking for target with name: \(targetName)")
        let targets = project.pbxproj.targets(named: targetName)

        guard let target = targets.first else { throw Error.targetNotFound }
        guard targets.count == 1 else { throw Error.multipleTargetsWithSameName }
        guard let list = target.buildConfigurationList else { throw Error.configurationsNotFound }

        let configurations = list.buildConfigurations.map { $0.name }

        if !isSilent {
            print("\nTarget: " + crayon.yellow.on(target.name))
            print("\nConfigurations:")
            print(configurations.map({ "  * \(crayon.yellow.on($0))" }).joined(separator: "\n"))
        }

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
        if !isSilent {
            print("\nGenerating output:\n  \(crayon.blue.on(directory.appendingPathComponent(filename).path))")
        }

        // Prepare
        var cases = configurations.map { name -> String in
            return "    case \(name.lowercased().sanitized) = \"\(name.uppercased().sanitized)\""
        }.joined(separator: "\n")

        if defaultConfig == nil && !configurations.contains("Release") {
            cases.append("\n    case unknown")
        }

        let current = configurations.enumerated().map { offet, name -> String in
            let statement = offet == 0 ? "#if" : "#elseif"
            return """
                    \(statement) \(name.uppercased().sanitized)
                    return .\(name.lowercased().sanitized)
            """
        }.joined(separator: "\n")

        let defaultEnvironment: String = {
            if let config = defaultConfig?.lowercased().sanitized {
                return "        return .\(config)"
            } else if configurations.contains("Release") {
                return "        return .release"
            } else {
                return "        return .unknown"
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
        for target: String?,
        to output: URL
    ) throws {
        let targetName = target ?? path.lastComponent.replacingOccurrences(of: ".xcodeproj", with: "")
        let targets = project.pbxproj.targets(named: targetName)

        guard let target = targets.first else { throw Error.targetNotFound }

        // Update project compile flags
        target.buildConfigurationList?.buildConfigurations.forEach { buildConfig in
            let flag = "-D\(buildConfig.name.uppercased().sanitized)"
            var flags = buildConfig.buildSettings["OTHER_SWIFT_FLAGS"] as? [String] ?? []
            guard !flags.contains(flag) else { return }

            if !flags.contains("$(inherited)") {
                flags.append("$(inherited)")
            }

            flags.append(flag)
            buildConfig.buildSettings["OTHER_SWIFT_FLAGS"] = flags
        }
        project.pbxproj.add(object: target)

        try project.pbxproj.write(path: XcodeProj.pbxprojPath(path), override: true)
    }

    public func skipUpdateCustomSwiftCompilerFlags(for target: String?) throws {
        guard !isSilent else { return }

        let targetName = target ?? path.lastComponent.replacingOccurrences(of: ".xcodeproj", with: "")
        let targets = project.pbxproj.targets(named: targetName)

        guard let target = targets.first else { throw Error.targetNotFound }

        print(crayon.yellow.bold.on("\nWARNING: Skipping updating Swift compiler flags!!!"))
        print(
            crayon.yellow.on("Please remember to add in build settings to ").rendered +
            crayon.yellow.bold.on("OTHER_SWIFT_FLAGS").rendered
        )

        // Just print
        target.buildConfigurationList?.buildConfigurations.forEach { buildConfig in
            let flag = "-D\(buildConfig.name.uppercased().sanitized)"
            print("  * " + crayon.yellow.on("\(flag) for \(buildConfig.name)"))
        }
        print("")
    }

    // MARK: - Helpers
    private enum TemplateKey: String {
        case enumName = "{{ENV_NAME}}"
        case cases = "{{ENV_CASES}}"
        case current = "{{ENV_CURRENT}}"
        case defaultConfig = "{{ENV_DEFAULT}}"
    }
}

private let template =
"""
// Generated with AutoEnvironment \(version) by Andrzej Michnia @GirAppe

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Abstraction for build configuration/environment
public enum {{ENV_NAME}}: String {
{{ENV_CASES}}

    public static var current: {{ENV_NAME}} {
        if let override = {{ENV_NAME}}.Override.current {
            return override
        }

{{ENV_CURRENT}}
        #else
{{ENV_DEFAULT}}
        #endif
    }

    public struct Override {
        public static var current: {{ENV_NAME}}?
    }
}

// MARK: - Formatting info

public extension {{ENV_NAME}} {

    var formattedInfo: String {
        var value = (formatForEnvironment[self] ?? defaultFormat).string
        value = value.replacingOccurrences(
            of: Format.Key.environmentName.rawValue,
            with: name)
        value = value.replacingOccurrences(
            of: Format.Key.environmentFirstLetter.rawValue,
            with: abbreviatedName)
        value = value.replacingOccurrences(
            of: Format.Key.versionNumber.rawValue,
            with: appVersion)
        value = value.replacingOccurrences(
            of: Format.Key.buildNumber.rawValue,
            with: appBuildNumber)
        return value
    }

    static func setVersionFormat(_ format: Format) {
        defaultFormat = format
        #if os(iOS)
        {{ENV_NAME}}.info.update()
        #endif
    }

    static func setVersionFormat(_ format: Format, for environment: {{ENV_NAME}}) {
        formatForEnvironment[environment] = format
        #if os(iOS)
        {{ENV_NAME}}.info.update()
        #endif
    }

    enum Format {
        public enum Key: String {
            case environmentName
            case environmentFirstLetter
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
            case .simple: return "\\(Key.versionNumber) (\\(Key.buildNumber))"
            case .full: return "\\(Key.environmentName) \\(Format.simple.string)"
            case let .just(key): return key.rawValue
            case let .custom(format): return format
            }
        }
    }
}

// MARK: - Utils

public extension {{ENV_NAME}} {

    var name: String {
        return rawValue.capitalized
    }

    var abbreviatedName: String {
        return String(name.first!).capitalized
    }

    var appVersion: String {
        guard let infoDictionary = Bundle.main.infoDictionary else { return "unknown" }
        return infoDictionary["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    var appBuildNumber: String {
        guard let infoDictionary = Bundle.main.infoDictionary else { return "unknown" }
        return infoDictionary["CFBundleVersion"] as? String ?? "unknown"
    }
}

#if os(iOS) || os(tvOS)
fileprivate class DummyViewController: UIViewController {
    fileprivate static var shared = DummyViewController()

    #if os(iOS)
    fileprivate static var preferredStatusBarStyle: UIStatusBarStyle = .default {
        didSet { shared.setNeedsStatusBarAppearanceUpdate() }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return DummyViewController.preferredStatusBarStyle
    }
    #endif
}

public extension {{ENV_NAME}} {
    #if os(iOS)
    enum BarType {
        case white
        case black
    }
    static var statusBar: BarType {
        get {
            switch DummyViewController.preferredStatusBarStyle {
            case .default: return .black
            case .lightContent: return .white
            @unknown default: return .white
            }
        }
        set {
            switch newValue {
            case .black: DummyViewController.preferredStatusBarStyle = .default
            case .white: DummyViewController.preferredStatusBarStyle = .lightContent
            }
        }
    }
    #endif

    /// Info container - allows showing environment/configuration version information on top of everything
    static var info = Info()

    class Info {
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
            isHidden = false
            update()
        }

        public func hideVersion() {
            isHidden = true
            update()
        }

        private var uiwindow: UIWindow?
        private weak var label: UILabel?

        fileprivate init() {}

        private func setupWindowIfNeeded() {
            guard uiwindow == nil else { return }

            let window = UIWindow(frame: UIScreen.main.bounds)
            window.backgroundColor = .clear
            #if swift(>=4.2)
                window.windowLevel = UIWindow.Level.alert + 1
            #else
                window.windowLevel = UIWindowLevelAlert + 1
            #endif
            window.isUserInteractionEnabled = false

            let dummy = DummyViewController.shared
            dummy.view.backgroundColor = UIColor.clear
            window.rootViewController = dummy

            let marginRightView = UIView()
            marginRightView.translatesAutoresizingMaskIntoConstraints = false
            dummy.view.addSubview(marginRightView)
            marginRightView.backgroundColor = .clear
            if #available(iOS 11.0, *) {
                marginRightView.topAnchor.constraint(equalTo: dummy.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
            } else {
                marginRightView.topAnchor.constraint(equalTo: dummy.bottomLayoutGuide.topAnchor).isActive = true
            }
            marginRightView.bottomAnchor.constraint(equalTo: dummy.view.bottomAnchor).isActive = true
            marginRightView.rightAnchor.constraint(equalTo: dummy.view.rightAnchor, constant: 0).isActive = true
            marginRightView.widthAnchor.constraint(
                equalTo: marginRightView.heightAnchor,
                multiplier: 0.5
            ).isActive = true

            let marginLeftView = UIView()
            marginLeftView.translatesAutoresizingMaskIntoConstraints = false
            dummy.view.addSubview(marginLeftView)
            marginLeftView.backgroundColor = .clear
            marginLeftView.bottomAnchor.constraint(equalTo: dummy.view.bottomAnchor).isActive = true
            marginLeftView.leftAnchor.constraint(equalTo: dummy.view.leftAnchor, constant: 0).isActive = true
            marginLeftView.widthAnchor.constraint(equalTo: marginRightView.widthAnchor).isActive = true
            marginLeftView.heightAnchor.constraint(equalTo: marginRightView.heightAnchor).isActive = true

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            dummy.view.addSubview(label)
            label.rightAnchor.constraint(equalTo: marginRightView.leftAnchor, constant: -4).isActive = true
            label.leftAnchor.constraint(equalTo: marginLeftView.rightAnchor, constant: 4).isActive = true
            label.bottomAnchor.constraint(equalTo: dummy.view.bottomAnchor, constant: -1).isActive = true
            label.heightAnchor.constraint(equalToConstant: 12).isActive = true
            label.font = UIFont.systemFont(ofSize: 8)
            label.text = {{ENV_NAME}}.current.formattedInfo
            label.textAlignment = textAlignment
            label.textColor = textColor
            label.shadowColor = shadowColor
            #if swift(>=4.2)
                dummy.view.bringSubviewToFront(label)
            #else
                dummy.view.bringSubview(toFront: label)
            #endif

            uiwindow = window
            self.label = label
        }

        fileprivate func update() {
            if !isHidden {
                setupWindowIfNeeded()
            }
            label?.text = {{ENV_NAME}}.current.formattedInfo
            label?.textAlignment = textAlignment
            label?.textColor = textColor
            label?.shadowColor = shadowColor

            uiwindow?.isHidden = isHidden
        }
    }
}
#endif

// MARK: - Private

private var defaultFormat: {{ENV_NAME}}.Format = .full
private var formatForEnvironment: [{{ENV_NAME}}: {{ENV_NAME}}.Format] = [:]
"""

private extension String {
    mutating func replace<K: RawRepresentable>(
        key: K,
        with value: String
    ) where K.RawValue == String {
        self = replacingOccurrences(of: key.rawValue, with: value)
    }
}
