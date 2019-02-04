#!/usr/bin/swift

import Foundation
import xcodeproj
import PathKit

// MARK: - Requirements

let requirements = Requirements(
    usage: "autoenvironment <options>",
    overview: "Use it to generate Environment enum based on specified target build ocnfigurations"
)

let help = Argument(
    info: "\tShow available options",
    name: "--help",
    shortName: "-h",
    kind: Bool.self
)
requirements.add(help)

let path = Argument(
    info: "\t[Required] Path to xcode project",
    name: "--path",
    shortName: "-p",
    kind: URL.self
)
requirements.add(path)

let target = Argument(
    info: "\t[Required] Target name",
    name: "--target",
    shortName: "-t",
    kind: String.self
)
requirements.add(target)

let output = Argument(
    info: "\t[Required] Output directory (with optional filename.swift)",
    name: "--output",
    shortName: "-o",
    kind: URL.self
)
requirements.add(output)

let updateBuildFlags = Argument(
    info: "\t[Optional] Should update build flags. If false, you need to update them manually",
    name: "--flags",
    shortName: "-f",
    kind: Bool.self,
    defaultValue: true
)
requirements.add(updateBuildFlags)

let defaultConfig = OptionalArgument(
    info: "[Optional] Default configuration (e.x. Release)",
    name: "--default-config",
    shortName: "-d",
    kind: String.self
)
requirements.add(defaultConfig)

let enumName = Argument(
    info: "[Optional] Generated Environment enum name",
    name: "--default-name",
    shortName: "-n",
    kind: String.self,
    defaultValue: "Environment"
)
requirements.add(enumName)

// MARK: - Main

guard let parsed = try? requirements.parse(CommandLine.arguments) else {
    print("Failed. Wrong argumtns")
    exit(1)
}

guard try !parsed.value(for: help) else {
    requirements.printInfo()
    exit(0)
}

guard
    let project = try? parsed.value(for: path),
    let outputUrl = try? parsed.value(for: output),
    let target = try? parsed.value(for: target)
else {
    print("Failure: ")
    print(parsed.errors.joined(separator: "\n"))
    print("")
    requirements.printInfo()
    exit(0)
}

print("Will scan xcode project: \(project.absoluteString)")
print("Will output generated file to: \(outputUrl.absoluteString)")

do {
    let generator = try Generator(project: project)
    try generator.generateEnvironment(
        for: target,
        to: outputUrl,
        enumName: try parsed.value(for: enumName),
        defaultConfig: try parsed.value(for: defaultConfig)
    )

    if try parsed.value(for: updateBuildFlags) {
        try generator.updateCustomSwiftCompilerFlags(
            for: target,
            to: outputUrl
        )
    }

    exit(0)
} catch {
    print("Failed: \(error)")
    print(parsed.errors.joined(separator: "\n"))
    exit(1)
}
