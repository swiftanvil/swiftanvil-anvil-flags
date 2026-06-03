import Foundation

/// The public API for reading feature flags.
///
/// Uses a singleton pattern with `@TaskLocal` for safe test injection.
/// All static methods read from `Self.current`, which defaults to a shared
/// system but can be overridden per-task via `withSystem()`.
public struct FeatureFlags: Sendable {
    @TaskLocal private static var current: FeatureFlagSystem = FeatureFlagSystem()
    
    // MARK: - Configuration
    
    /// Configures the shared flag system with the given sources.
    public static func configure(sources: [FeatureFlagSource]) async {
        await Self.current.configure(sources: sources)
    }
    
    // MARK: - Flag Reads
    
    /// Returns true if the flag exists and is a boolean true.
    public static func isEnabled(_ key: FeatureFlagKey) async -> Bool {
        await Self.current.isEnabled(key)
    }
    
    /// Returns the flag value converted to the requested type, or the default.
    public static func value<T: FeatureFlagValueConvertible>(
        _ key: FeatureFlagKey,
        as type: T.Type = T.self,
        default defaultValue: T
    ) async -> T {
        if let raw = await Self.current.value(for: key),
           let converted = T.convert(from: raw) {
            return converted
        }
        return defaultValue
    }
    
    // MARK: - A/B Testing
    
    /// Assigns a user to an A/B test variant.
    public static func abTest(_ test: ABTest, forUser userID: String) async -> ABTestAssignment {
        await Self.current.abTest(test, forUser: userID)
    }
    
    // MARK: - Test Injection
    
    /// Runs an operation with a custom flag system, isolated to this task.
    ///
    /// Use this in tests to inject mock flags without affecting the shared state:
    ///
    /// ```swift
    /// let testSystem = FeatureFlagSystem(sources: [
    ///     InMemoryFeatureFlagSource([.feature: .bool(true)])
    /// ])
    /// await FeatureFlags.withSystem(testSystem) {
    ///     #expect(await FeatureFlags.isEnabled(.feature) == true)
    /// }
    /// ```
    public static func withSystem<T>(
        _ system: FeatureFlagSystem,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await $current.withValue(system) {
            try await operation()
        }
    }
}
