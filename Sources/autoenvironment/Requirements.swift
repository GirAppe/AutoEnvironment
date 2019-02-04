import Foundation

// MARK: - Helpers
extension Array {
    subscript (safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}

extension String {
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }

    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - Parsable
protocol Parsable {
    static func parse(args: [String], at index: Int?) throws -> Self
}

extension String: Parsable {
    static func parse(args: [String], at index: Int?) throws -> String {
        guard let index = index else { throw ArgumentError.argumentMissing }
        guard let value = args[safe: index + 1] else { throw ArgumentError.parsingFailed }
        return value
    }
}

extension URL: Parsable {
    static func parse(args: [String], at index: Int?) throws -> URL {
        let stringValue = try String.parse(args: args, at: index)
        let defaultUrl = URL(fileURLWithPath: stringValue)

        if stringValue.starts(with: "/") {
            let parent = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return parent.appendingPathComponent(stringValue).standardizedFileURL
        } else if stringValue.starts(with: "http") {
            return URL(string: stringValue) ?? defaultUrl
        } else {
            return defaultUrl
        }
    }
}

extension Bool: Parsable {
    static func parse(args: [String], at index: Int?) throws -> Bool {
        return index != nil ? true : false
    }
}

extension Int: Parsable {
    static func parse(args: [String], at index: Int?) throws -> Int {
        let stringValue = try String.parse(args: args, at: index)
        if let value = Int(stringValue) {
            return value
        } else {
            throw ArgumentError.parsingFailed
        }
    }
}

// MARK: - Arguments Utils
enum ArgumentError: Error {
    case parsingFailed
    case argumentMissing
    case wrongType
    case typeNotAllowed
}

protocol AnyArgument: CustomStringConvertible {
    var info: String { get }
    var name: String { get }
    var shortName: String { get }
    var isOptional: Bool { get }

    func parsed(with args: [String]) throws -> Any?
}

class OptionalArgument<T: Parsable>: AnyArgument {
    let info: String
    let name: String
    let shortName: String
    var isOptional: Bool { return true }

    init(info: String, name: String, shortName: String, kind: T.Type) {
        self.info = info
        self.name = name
        self.shortName = shortName
    }

    func parsed(with args: [String]) throws -> Any? {
        return try parse(args: args)
    }

    private func parse(args: [String]) throws -> T? {
        return try? T.parse(args: args, at: args.lastIndex(of: name) ?? args.lastIndex(of: shortName))
    }

    var description: String {
        return "\t\(name), \(shortName)\t\(info), optional: \(isOptional)"
    }
}

class Argument<T: Parsable>: AnyArgument {
    let info: String
    let name: String
    let shortName: String
    var isOptional: Bool { return false }
    var defaultValue: T?

    init(info: String, name: String, shortName: String, kind: T.Type, defaultValue: T? = nil) {
        self.info = info
        self.name = name
        self.shortName = shortName
        self.defaultValue = defaultValue
    }

    func parsed(with args: [String]) throws -> Any? {
        return try? parse(args: args)
    }

    private func parse(args: [String]) throws -> T {
        do {
            return try T.parse(args: args, at: args.lastIndex(of: name) ?? args.lastIndex(of: shortName))
        } catch ArgumentError.argumentMissing where defaultValue != nil {
            return defaultValue!
        } catch {
            throw error
        }
    }

    var description: String {
        if let def = defaultValue {
            return "\t\(name), \(shortName)\t\(info), default: \(def)"
        } else {
            return "\t\(name), \(shortName)\t\(info)"
        }
    }
}

class Requirements {
    var arguments: [AnyArgument]
    let usage: String
    let overview: String

    init(usage: String, overview: String) {
        self.arguments = []
        self.usage = usage
        self.overview = overview
    }

    func add<T>(_ argument: Argument<T>) {
        guard !arguments.contains(where: { $0.name == argument.name }) else { return }
        arguments.append(argument)
    }

    func add<T>(_ argument: OptionalArgument<T>) {
        guard !arguments.contains(where: { $0.name == argument.name }) else { return }
        arguments.append(argument)
    }

    func parse(_ args: [String]) throws -> ParsedArguments {
        return try ParsedArguments(requirements: self, args: args)
    }

    func printInfo() {
        print("OVERVIEW: \(overview)\n")
        print("USAGE: \(usage)\n")
        print("OPTIONS:")
        for r in arguments {
            print(r)
        }
    }
}

struct ParsedArguments {
    private var parsed: [String: Any] = [:]
    var errors: [String] = []

    init(requirements: Requirements, args: [String]) throws {
        for argument in requirements.arguments {
            if let value = try argument.parsed(with: args) {
                parsed[argument.name] = value
            } else if !argument.isOptional {
                errors.append("\(argument.name) is required")
            }
        }
    }

    func value<T>(for argument: Argument<T>) throws -> T {
        guard let value = parsed[argument.name] as? T else { throw ArgumentError.argumentMissing }
        return value
    }

    func value<T>(for argument: OptionalArgument<T>) throws -> T? {
        guard let value = parsed[argument.name] as? T else { return nil }
        return value
    }
}
