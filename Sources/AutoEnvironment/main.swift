#!/usr/bin/swift

import Foundation
import xcodeproj
import PathKit
import Crayon

// MARK: - Requirements
var isSilent: Bool = false
let version = "0.3.0"

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

let toolVersion = Argument(
    info: "\tPrint tool version",
    name: "--version",
    shortName: "-v",
    kind: Bool.self
)
requirements.add(toolVersion)

let path = Argument(
    info: "\tPath to xcode project",
    name: "--path",
    shortName: "-p",
    kind: URL.self
)
requirements.add(path)

let target = OptionalArgument(
    info: "\tTarget name. If not specified, will use Project name",
    name: "--target",
    shortName: "-t",
    kind: String.self
)
requirements.add(target)

let output = Argument(
    info: "\tOutput directory (with optional filename.swift)",
    name: "--output",
    shortName: "-o",
    kind: URL.self
)
requirements.add(output)

let skipUpdateFlags = OptionalArgument(
    info: "\tSkip update build flags. If flag present, you need to update them manually",
    name: "--no-flags",
    shortName: "-f",
    kind: Bool.self
)
requirements.add(skipUpdateFlags)

let defaultConfig = OptionalArgument(
    info: "Default configuration (e.x. Release)",
    name: "--default-config",
    shortName: "-d",
    kind: String.self
)
requirements.add(defaultConfig)

let enumName = Argument(
    info: "Generated Environment enum name",
    name: "--default-name",
    shortName: "-n",
    kind: String.self,
    defaultValue: "Environment"
)
requirements.add(enumName)

let silent = OptionalArgument(
    info: "\tIf flag present, supresses all console logs and prints",
    name: "--silent",
    shortName: "-s",
    kind: Bool.self
)
requirements.add(silent)

// MARK: - Main

guard let parsed = try? requirements.parse(CommandLine.arguments) else { exit(1) }

isSilent = try parsed.value(for: silent) ?? false

let parsingFailure: () -> Swift.Never = {
    if !isSilent {
        print(crayon.red.on("Failure: "))
        print(crayon.red.on(parsed.errors.joined(separator: "\n")))
        print("")
        requirements.printInfo()
    }
    exit(1)
}

guard try !parsed.value(for: help) else {
    requirements.printInfo()
    exit(0)
}

guard try !parsed.value(for: toolVersion) else {
    print("\(version) \(Environment.current.name)")
    exit(0)
}

guard let project = try? parsed.value(for: path) else { parsingFailure() }
guard let outputUrl = try? parsed.value(for: output) else { parsingFailure() }

let targetName = try parsed.value(for: target)

if !isSilent {
    print("\nScaning xcode project:\n  \(crayon.blue.on(project.path))")
}

let generator = try Generator(project: project)
try generator.generateEnvironment(
    for: targetName,
    to: outputUrl,
    enumName: try parsed.value(for: enumName),
    defaultConfig: try parsed.value(for: defaultConfig)
)

let skip = try parsed.value(for: skipUpdateFlags) ?? false
if skip {
    try generator.skipUpdateCustomSwiftCompilerFlags(for: targetName)
} else {
    try generator.updateCustomSwiftCompilerFlags(for: targetName, to: outputUrl)
}

exit(0)
