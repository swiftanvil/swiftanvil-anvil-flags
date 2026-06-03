import Foundation

/// A type-safe key for identifying a feature flag.
public struct FeatureFlagKey: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
