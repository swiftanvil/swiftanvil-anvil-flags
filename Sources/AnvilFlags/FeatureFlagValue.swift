import Foundation

/// The value of a feature flag.
public enum FeatureFlagValue: Sendable, Equatable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)
    case json(Data)
}

// MARK: - Typed Conversion Protocol

/// A type that can be converted from a `FeatureFlagValue`.
public protocol FeatureFlagValueConvertible: Sendable {
    static func convert(from value: FeatureFlagValue) -> Self?
}

// MARK: - Direct Conformances (concrete wins over Decodable fallback)

extension Bool: FeatureFlagValueConvertible {
    public static func convert(from value: FeatureFlagValue) -> Bool? {
        if case .bool(let v) = value { return v }
        return nil
    }
}

extension Int: FeatureFlagValueConvertible {
    public static func convert(from value: FeatureFlagValue) -> Int? {
        if case .int(let v) = value { return v }
        return nil
    }
}

extension Double: FeatureFlagValueConvertible {
    public static func convert(from value: FeatureFlagValue) -> Double? {
        if case .double(let v) = value { return v }
        return nil
    }
}

extension String: FeatureFlagValueConvertible {
    public static func convert(from value: FeatureFlagValue) -> String? {
        if case .string(let v) = value { return v }
        return nil
    }
}

extension Data: FeatureFlagValueConvertible {
    public static func convert(from value: FeatureFlagValue) -> Data? {
        if case .json(let v) = value { return v }
        return nil
    }
}

// MARK: - Decodable Fallback

extension FeatureFlagValueConvertible where Self: Decodable {
    public static func convert(from value: FeatureFlagValue) -> Self? {
        // First try direct conversion (for Data, Bool, etc.)
        // This is a no-op for pure Decodable types since they have no direct case
        // The concrete conformances above take precedence via Swift overload resolution
        if let direct = Self._directConvert(from: value) {
            return direct
        }
        // Fall back to JSON decoding
        if case .json(let data) = value {
            return try? JSONDecoder().decode(Self.self, from: data)
        }
        return nil
    }
    
    // Hook for concrete types to short-circuit
    private static func _directConvert(from value: FeatureFlagValue) -> Self? {
        return nil
    }
}
