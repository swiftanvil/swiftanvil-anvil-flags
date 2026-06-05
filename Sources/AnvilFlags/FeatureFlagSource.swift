import Foundation
import AnvilCore

/// A source of feature flag values.
public protocol FeatureFlagSource: Sendable {
    /// Returns the value for a given key, or nil if not found.
    func value(for key: FeatureFlagKey) async -> FeatureFlagValue?
    
    /// Returns all flags from this source. Default: empty (sources that don't enumerate).
    func allFlags() async -> [FeatureFlagKey: FeatureFlagValue]
}

extension FeatureFlagSource {
    public func allFlags() async -> [FeatureFlagKey: FeatureFlagValue] {
        [:]
    }
}

// MARK: - Configuration Source

/// A feature flag source backed by `AnvilConfiguration`.
public struct ConfigurationFeatureFlagSource: FeatureFlagSource {
    private let configuration: AnvilConfiguration
    
    /// Creates a source that reads from the given `AnvilConfiguration`.
    public init(configuration: AnvilConfiguration) {
        self.configuration = configuration
    }
    
    public func value(for key: FeatureFlagKey) async -> FeatureFlagValue? {
        if let boolValue: Bool = await configuration.get(key.rawValue) {
            return .bool(boolValue)
        }
        if let intValue: Int = await configuration.get(key.rawValue) {
            return .int(intValue)
        }
        if let doubleValue: Double = await configuration.get(key.rawValue) {
            return .double(doubleValue)
        }
        if let stringValue: String = await configuration.get(key.rawValue) {
            return .string(stringValue)
        }
        return nil
    }
    
    public func allFlags() async -> [FeatureFlagKey: FeatureFlagValue] {
        let allKeys = await configuration.keys
        var result: [FeatureFlagKey: FeatureFlagValue] = [:]
        for key in allKeys {
            if let value = await self.value(for: FeatureFlagKey(key)) {
                result[FeatureFlagKey(key)] = value
            }
        }
        return result
    }
}

// MARK: - InMemory Source

/// An in-memory feature flag source. Mutable before configuration.
public struct InMemoryFeatureFlagSource: FeatureFlagSource {
    private var storage: [FeatureFlagKey: FeatureFlagValue]
    
    public init(_ flags: [FeatureFlagKey: FeatureFlagValue] = [:]) {
        self.storage = flags
    }
    
    public mutating func set(_ value: FeatureFlagValue, for key: FeatureFlagKey) {
        storage[key] = value
    }
    
    public func value(for key: FeatureFlagKey) async -> FeatureFlagValue? {
        storage[key]
    }
    
    public func allFlags() async -> [FeatureFlagKey: FeatureFlagValue] {
        storage
    }
}

// MARK: - JSON File Source

/// Loads feature flags from a JSON file in a bundle.
public struct JSONFileFeatureFlagSource: FeatureFlagSource {
    private let fileName: String
    private let bundle: Bundle
    private let flags: [FeatureFlagKey: FeatureFlagValue]
    
    public init(fileName: String, bundle: Bundle = .main) throws {
        self.fileName = fileName
        self.bundle = bundle
        self.flags = try Self.load(fileName: fileName, bundle: bundle)
    }
    
    public func value(for key: FeatureFlagKey) async -> FeatureFlagValue? {
        flags[key]
    }
    
    public func allFlags() async -> [FeatureFlagKey: FeatureFlagValue] {
        flags
    }
    
    private static func load(fileName: String, bundle: Bundle) throws -> [FeatureFlagKey: FeatureFlagValue] {
        guard let url = bundle.url(forResource: fileName, withExtension: nil) ?? bundle.url(forResource: fileName, withExtension: "json") else {
            throw FeatureFlagError.fileNotFound(fileName)
        }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw FeatureFlagError.jsonDecodingFailed("Top level must be a JSON object")
        }
        var result: [FeatureFlagKey: FeatureFlagValue] = [:]
        for (key, value) in dict {
            result[FeatureFlagKey(key)] = Self.convert(value)
        }
        return result
    }
    
    private static func convert(_ value: Any) -> FeatureFlagValue {
        switch value {
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        default:
            // Nested objects/arrays → re-encode as JSON Data
            if let data = try? JSONSerialization.data(withJSONObject: value) {
                return .json(data)
            }
            return .string(String(describing: value))
        }
    }
}
