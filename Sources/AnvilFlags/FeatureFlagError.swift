import Foundation

/// Errors that can occur when working with feature flags.
public enum FeatureFlagError: Error, Sendable {
    case fileNotFound(String)
    case jsonDecodingFailed(String)
    case notConfigured
}
