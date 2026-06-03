import Foundation

/// The actor-backed system that resolves feature flags.
public actor FeatureFlagSystem: Sendable {
    private var sources: [FeatureFlagSource]
    private let bucketing: ABTestBucketingStrategy
    private var abCache: [String: ABTestAssignment] = [:]
    
    public init(
        sources: [FeatureFlagSource] = [],
        bucketing: ABTestBucketingStrategy = StableHashBucketingStrategy()
    ) {
        self.sources = sources
        self.bucketing = bucketing
    }
    
    /// Replaces all sources. Atomic — concurrent reads see old or new, never partial.
    public func configure(sources: [FeatureFlagSource]) {
        self.sources = sources
        self.abCache = [:] // Clear A/B cache on reconfiguration
    }
    
    /// Resolves a flag value by querying sources in priority order.
    public func value(for key: FeatureFlagKey) async -> FeatureFlagValue? {
        for source in sources {
            if let value = await source.value(for: key) {
                return value
            }
        }
        return nil
    }
    
    /// Returns true if the flag is enabled (bool value is true).
    public func isEnabled(_ key: FeatureFlagKey) async -> Bool {
        if let value = await value(for: key) {
            if case .bool(let enabled) = value { return enabled }
        }
        return false
    }
    
    /// Assigns a user to an A/B test variant.
    public func abTest(_ test: ABTest, forUser userID: String) -> ABTestAssignment {
        let cacheKey = "\(userID)|\(test.name)"
        if let cached = abCache[cacheKey] {
            return cached
        }
        let variant = bucketing.assign(test, for: userID)
        let assignment = ABTestAssignment(test: test, variant: variant)
        abCache[cacheKey] = assignment
        return assignment
    }
    
    /// Returns all flags from all sources (for Developer Menu / debugging).
    public func allFlags() async -> [FeatureFlagKey: FeatureFlagValue] {
        var result: [FeatureFlagKey: FeatureFlagValue] = [:]
        for source in sources {
            let flags = await source.allFlags()
            for (key, value) in flags {
                if result[key] == nil {
                    result[key] = value
                }
            }
        }
        return result
    }
}
