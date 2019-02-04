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
    info: "Show available options",
    name: "--help",
    shortName: "-h",
    kind: Bool.self
)
requirements.add(help)

let path = Argument(
    info: "[Required] Path to xcode project",
    name: "--path",
    shortName: "-p",
    kind: URL.self
)
requirements.add(path)

let target = Argument(
    info: "[Required] Target name",
    name: "--target",
    shortName: "-t",
    kind: String.self
)
requirements.add(target)

let output = Argument(
    info: "[Required] Output directory (with optional filename.swift)",
    name: "--output",
    shortName: "-o",
    kind: URL.self
)
requirements.add(output)

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
    try generator.generateEnvironment(for: target, to: outputUrl)
    exit(0)
} catch {
    print("Failed: \(error)")
    exit(1)
}
