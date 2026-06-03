import Foundation

/// An A/B test definition.
public struct ABTest: Sendable {
    public let name: String
    public let variants: [String]
    
    public init(name: String, variants: [String]) {
        precondition(!variants.isEmpty, "ABTest must have at least one variant")
        self.name = name
        self.variants = variants
    }
}

/// The result of assigning a user to an A/B test variant.
public struct ABTestAssignment: Sendable {
    public let test: ABTest
    public let variant: String
}

// MARK: - Bucketing Strategy

/// Determines which variant a user is assigned to.
public protocol ABTestBucketingStrategy: Sendable {
    func assign(_ test: ABTest, for userID: String) -> String
}

// MARK: - FNV-1a Stable Hash Bucketing

/// Uses FNV-1a (32-bit) for stable, deterministic, cross-platform bucketing.
/// No CryptoKit dependency. Works on Linux.
public struct StableHashBucketingStrategy: ABTestBucketingStrategy {
    public init() {}
    
    public func assign(_ test: ABTest, for userID: String) -> String {
        let hash = fnv1a32("\(userID)|\(test.name)")
        let index = Int(hash % UInt32(test.variants.count))
        return test.variants[index]
    }
}

/// FNV-1a 32-bit hash. Pure Swift, no dependencies.
func fnv1a32(_ string: String) -> UInt32 {
    var hash: UInt32 = 2166136261 // FNV offset basis
    let prime: UInt32 = 16777619   // FNV prime
    
    for byte in string.utf8 {
        hash ^= UInt32(byte)
        hash &*= prime
    }
    
    return hash
}
