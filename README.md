# AnvilFlags

> Type-safe, extensible feature flags for Swift with A/B test support.

## Overview

AnvilFlags provides a concurrent, Swift 6-strict feature flag system with:

- **Type-safe flag keys**: `FeatureFlagKey` prevents typos and enables autocomplete
- **Pluggable sources**: In-memory, JSON file, or custom remote adapters
- **Source priority**: Query sources in order, first match wins
- **A/B testing**: Stable, deterministic bucketing with FNV-1a hashing
- **Test injection**: `@TaskLocal`-scoped mock systems for parallel-safe tests
- **Zero dependencies**: Pure Swift, works on all Apple platforms + Linux

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/swiftanvil/swiftanvil-anvil-flags.git", from: "1.0.0"),
]
```

```swift
targets: [.target(name: "MyTarget", dependencies: [.product(name: "AnvilFlags", package: "swiftanvil-anvil-flags")])]
```

## Quick Start

```swift
import AnvilFlags

// Define flags in one place
extension FeatureFlagKey {
    static let newOnboarding = FeatureFlagKey("new_onboarding")
    static let maxRetries = FeatureFlagKey("max_retries")
    static let apiEndpoint = FeatureFlagKey("api_endpoint")
}

// Configure once at app launch
await FeatureFlags.configure(sources: [
    InMemoryFeatureFlagSource([
        .newOnboarding: .bool(false),
        .maxRetries: .int(3)
    ]),
    JSONFileFeatureFlagSource(fileName: "flags.json")
])

// Read flags anywhere
if await FeatureFlags.isEnabled(.newOnboarding) {
    showNewOnboarding()
}

let maxRetries = await FeatureFlags.value(.maxRetries, as: Int.self, default: 3)
let endpoint = await FeatureFlags.value(.apiEndpoint, as: String.self, default: "https://api.example.com")

// A/B test
let assignment = await FeatureFlags.abTest(
    ABTest(name: "checkout_flow", variants: ["control", "variant_a"]),
    forUser: userID
)
if assignment.variant == "variant_a" {
    showVariantA()
}
```

## Testing

**Important:** Always use `withSystem()` in tests. Never call `configure()` from tests — it mutates the shared state and will pollute parallel tests.

```swift
let testSystem = FeatureFlagSystem(sources: [
    InMemoryFeatureFlagSource([.newOnboarding: .bool(true)])
])

await FeatureFlags.withSystem(testSystem) {
    #expect(await FeatureFlags.isEnabled(.newOnboarding) == true)
}
```

## Architecture

```
AnvilFlags
├── FeatureFlags.swift            # Public API (TaskLocal singleton)
├── FeatureFlagSystem.swift       # Actor-isolated core
├── FeatureFlagKey.swift          # Type-safe flag keys
├── FeatureFlagValue.swift        # Flag values + conversion protocol
├── FeatureFlagSource.swift       # Source protocol + built-in sources
├── ABTest.swift                  # A/B testing + FNV-1a bucketing
└── FeatureFlagError.swift        # Error types
```

## Requirements

- iOS 16+ / macOS 13+ / tvOS 16+ / watchOS 9+ / visionOS 1+
- Swift 6.0+

## License

MIT
