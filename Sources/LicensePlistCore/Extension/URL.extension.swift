import Foundation
import LoggerAPI

extension URL: LicensePlistCompatible {}

extension LicensePlistExtension where Base == URL {
    func download() -> ResultOperation<String, Error> {
        let operation = ResultOperation<String, Error> { _ in
            do {
                return Result(catching: {
                    try String(contentsOf: self.base)
                })
            }
        }
        return operation
    }
}

extension LicensePlistExtension where Base == URL {
    var fm: FileManager { .default }

    public var isExists: Bool { return fm.fileExists(atPath: base.path) }

    public var isDirectory: Bool {
        var result: ObjCBool = false
        fm.fileExists(atPath: base.path, isDirectory: &result)
        return result.boolValue
    }

    public func read() -> String? {
        if !isExists {
            Log.warning("Not found: \(base).")
            return nil
        }
        return getResultOrDefault {
            try String(contentsOf: base, encoding: Consts.encoding)
        }
    }

    public func write(content: String) {
        return run {
            try content.write(to: base, atomically: false, encoding: Consts.encoding)
        }
    }

    public func deleteIfExits() -> Bool {
        if !isExists {
            return false
        }
        return getResultOrDefault {
            try fm.removeItem(at: base)
            return true
        }
    }

    public func createDirectory(withIntermediateDirectories: Bool = true) {
        return run {
            try fm.createDirectory(at: base,
                                   withIntermediateDirectories: withIntermediateDirectories,
                                   attributes: nil)
        }
    }

    public func listDir() -> [URL] {
        return getResultOrDefault {
            try fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: [])
        }
    }

    private func getResultOrDefault<T: HasDefaultValue>(closure: () throws -> T) -> T {
        do {
            return try closure()
        } catch let e {
            handle(error: e)
            return T.default
        }
    }
    private func run(closure: () throws -> Void) {
        do {
            try closure()
        } catch let e {
            handle(error: e)
        }
    }
    private func handle(error: Error) {
        let message = String(describing: error)
        assertionFailure(message)
        Log.error(message)
    }
    internal var fileURL: URL {
        return URL(fileURLWithPath: base.absoluteString)
    }
}

protocol HasDefaultValue {
    static var `default`: Self { get }
}

extension Bool: HasDefaultValue {
    static var `default`: Bool { return false }
}

extension Array: HasDefaultValue {
    static var `default`: [Element] { return [] }
}

extension Optional: HasDefaultValue {
    static var `default`: Wrapped? { return nil }
}
