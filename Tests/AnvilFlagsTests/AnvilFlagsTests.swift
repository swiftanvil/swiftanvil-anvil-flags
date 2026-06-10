import AnvilCore
import Foundation
import Testing
@testable import AnvilFlags

// MARK: - FeatureFlagKey Tests

@Suite("FeatureFlagKey")
struct FeatureFlagKeyTests {
    @Test("init with string")
    func initWithString() {
        let key = FeatureFlagKey("test_feature")
        #expect(key.rawValue == "test_feature")
    }

    @Test("is Hashable")
    func hashable() {
        let a = FeatureFlagKey("a")
        let b = FeatureFlagKey("a")
        let c = FeatureFlagKey("b")
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - FeatureFlagValue Tests

@Suite("FeatureFlagValue")
struct FeatureFlagValueTests {
    @Test("bool case")
    func boolCase() {
        let value = FeatureFlagValue.bool(true)
        if case let .bool(v) = value {
            #expect(v == true)
        } else {
            Issue.record("Expected bool case")
        }
    }

    @Test("is Sendable")
    func sendable() {
        let value: FeatureFlagValue = .int(42)
        _ = value as Sendable
    }
}

// MARK: - FeatureFlagValueConvertible Tests

@Suite("FeatureFlagValueConvertible")
struct FeatureFlagValueConvertibleTests {
    @Test("Bool converts from bool")
    func boolConvert() {
        #expect(Bool.convert(from: .bool(true)) == true)
        #expect(Bool.convert(from: .int(1)) == nil)
    }

    @Test("Int converts from int")
    func intConvert() {
        #expect(Int.convert(from: .int(42)) == 42)
        #expect(Int.convert(from: .bool(true)) == nil)
    }

    @Test("Double converts from double")
    func doubleConvert() {
        #expect(Double.convert(from: .double(3.14)) == 3.14)
    }

    @Test("String converts from string")
    func stringConvert() {
        #expect(String.convert(from: .string("hello")) == "hello")
    }

    @Test("Data converts from json (direct unwrap)")
    func dataConvert() {
        let data = Data("{\"x\":1}".utf8)
        #expect(Data.convert(from: .json(data)) == data)
    }

    @Test("Decodable converts from json")
    func decodableConvert() {
        struct Config: Codable, FeatureFlagValueConvertible { }
        let data = Data("{\"name\":\"test\"}".utf8)
        let config = Config.convert(from: .json(data))
        #expect(config != nil)
    }
}

// MARK: - InMemoryFeatureFlagSource Tests

@Suite("InMemoryFeatureFlagSource")
struct InMemorySourceTests {
    @Test("stores and retrieves values")
    func storeRetrieve() async {
        var source = InMemoryFeatureFlagSource([
            FeatureFlagKey("flag1"): .bool(true),
            FeatureFlagKey("flag2"): .int(42)
        ])

        let v1 = await source.value(for: FeatureFlagKey("flag1"))
        let v2 = await source.value(for: FeatureFlagKey("flag2"))
        let v3 = await source.value(for: FeatureFlagKey("missing"))

        #expect(v1 == .bool(true))
        #expect(v2 == .int(42))
        #expect(v3 == nil)
    }

    @Test("set updates value")
    func setValue() async {
        var source = InMemoryFeatureFlagSource()
        source.set(.string("updated"), for: FeatureFlagKey("flag"))

        let value = await source.value(for: FeatureFlagKey("flag"))
        #expect(value == .string("updated"))
    }

    @Test("allFlags returns all stored flags")
    func allFlags() async {
        let source = InMemoryFeatureFlagSource([
            FeatureFlagKey("a"): .bool(true),
            FeatureFlagKey("b"): .int(1)
        ])

        let flags = await source.allFlags()
        #expect(flags.count == 2)
        #expect(flags[FeatureFlagKey("a")] == .bool(true))
    }
}

// MARK: - FeatureFlagSystem Tests

@Suite("FeatureFlagSystem")
struct FeatureFlagSystemTests {
    @Test("resolves value from single source")
    func singleSource() async {
        let system = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)])
        ])

        let value = await system.value(for: FeatureFlagKey("flag"))
        #expect(value == .bool(true))
    }

    @Test("source priority: first match wins")
    func sourcePriority() async {
        let system = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)]),
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(false)])
        ])

        let value = await system.value(for: FeatureFlagKey("flag"))
        #expect(value == .bool(true))
    }

    @Test("missing flag returns nil")
    func missingFlag() async {
        let system = FeatureFlagSystem()
        let value = await system.value(for: FeatureFlagKey("missing"))
        #expect(value == nil)
    }

    @Test("isEnabled returns true for bool true")
    func isEnabledTrue() async {
        let system = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)])
        ])
        #expect(await system.isEnabled(FeatureFlagKey("flag")) == true)
    }

    @Test("isEnabled returns false for bool false")
    func isEnabledFalse() async {
        let system = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(false)])
        ])
        #expect(await system.isEnabled(FeatureFlagKey("flag")) == false)
    }

    @Test("isEnabled returns false for missing flag")
    func isEnabledMissing() async {
        let system = FeatureFlagSystem()
        #expect(await system.isEnabled(FeatureFlagKey("flag")) == false)
    }

    @Test("configure replaces sources")
    func configureReplaces() async {
        let system = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)])
        ])

        await system.configure(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(false)])
        ])

        let value = await system.value(for: FeatureFlagKey("flag"))
        #expect(value == .bool(false))
    }

    @Test("allFlags merges sources with priority")
    func allFlags() async {
        let system = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("a"): .bool(true)]),
            InMemoryFeatureFlagSource([FeatureFlagKey("a"): .bool(false), FeatureFlagKey("b"): .int(1)])
        ])

        let flags = await system.allFlags()
        #expect(flags.count == 2)
        #expect(flags[FeatureFlagKey("a")] == .bool(true)) // First source wins
        #expect(flags[FeatureFlagKey("b")] == .int(1))
    }
}

// MARK: - FeatureFlags Static API Tests

@Suite("FeatureFlags")
struct FeatureFlagsTests {
    @Test("isEnabled via static API")
    func staticIsEnabled() async {
        let testSystem = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)])
        ])

        await FeatureFlags.withSystem(testSystem) {
            let enabled = await FeatureFlags.isEnabled(FeatureFlagKey("flag"))
            #expect(enabled == true)
        }
    }

    @Test("value with default")
    func staticValue() async {
        let testSystem = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("count"): .int(5)])
        ])

        await FeatureFlags.withSystem(testSystem) {
            let count = await FeatureFlags.value(FeatureFlagKey("count"), as: Int.self, default: 0)
            #expect(count == 5)
        }
    }

    @Test("value falls back to default when missing")
    func staticValueDefault() async {
        let testSystem = FeatureFlagSystem()

        await FeatureFlags.withSystem(testSystem) {
            let value = await FeatureFlags.value(FeatureFlagKey("missing"), as: Int.self, default: 42)
            #expect(value == 42)
        }
    }

    @Test("withSystem injects custom system")
    func withSystem() async {
        let testSystem = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)])
        ])

        await FeatureFlags.withSystem(testSystem) {
            let enabled = await FeatureFlags.isEnabled(FeatureFlagKey("flag"))
            #expect(enabled == true)
        }
    }

    @Test("withSystem isolation: default system unaffected")
    func withSystemIsolation() async {
        // Default system has no flags
        let testSystem = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([FeatureFlagKey("flag"): .bool(true)])
        ])

        await FeatureFlags.withSystem(testSystem) {
            #expect(await FeatureFlags.isEnabled(FeatureFlagKey("flag")) == true)
        }

        // Outside withSystem: default system still has no flag
        #expect(await FeatureFlags.isEnabled(FeatureFlagKey("flag")) == false)
    }
}

// MARK: - A/B Test Tests

@Suite("ABTest")
struct ABTestTests {
    @Test("assignment is deterministic")
    func deterministic() async {
        let system = FeatureFlagSystem()
        let test = ABTest(name: "checkout", variants: ["control", "variant_a"])

        let a1 = await system.abTest(test, forUser: "user123")
        let a2 = await system.abTest(test, forUser: "user123")

        #expect(a1.variant == a2.variant)
    }

    @Test("different users get potentially different variants")
    func differentUsers() async {
        let system = FeatureFlagSystem()
        let test = ABTest(name: "checkout", variants: ["control", "variant_a", "variant_b"])

        let a1 = await system.abTest(test, forUser: "user1")
        let a2 = await system.abTest(test, forUser: "user2")

        // They might be the same or different; just verify both are valid variants
        #expect(test.variants.contains(a1.variant))
        #expect(test.variants.contains(a2.variant))
    }

    @Test("different tests for same user are independent")
    func differentTests() async {
        let system = FeatureFlagSystem()
        let test1 = ABTest(name: "checkout", variants: ["control", "a"])
        let test2 = ABTest(name: "onboarding", variants: ["control", "b"])

        let a1 = await system.abTest(test1, forUser: "user1")
        let a2 = await system.abTest(test2, forUser: "user1")

        // Same user, different tests → independent assignments
        #expect(test1.variants.contains(a1.variant))
        #expect(test2.variants.contains(a2.variant))
    }

    @Test("assignment is cached")
    func cached() async {
        let system = FeatureFlagSystem()
        let test = ABTest(name: "checkout", variants: ["control", "variant_a"])

        let a1 = await system.abTest(test, forUser: "user123")
        let a2 = await system.abTest(test, forUser: "user123")

        // Same object reference (cached)
        #expect(a1.variant == a2.variant)
    }

    @Test("static API abTest")
    func staticABTest() async {
        let test = ABTest(name: "checkout", variants: ["control", "variant_a"])
        let assignment = await FeatureFlags.abTest(test, forUser: "user123")
        #expect(["control", "variant_a"].contains(assignment.variant))
    }
}

// MARK: - FNV-1a Tests

@Suite("FNV1a")
struct FNV1aTests {
    @Test("hash is stable")
    func stable() {
        let h1 = fnv1a32("test")
        let h2 = fnv1a32("test")
        #expect(h1 == h2)
    }

    @Test("different inputs produce different hashes")
    func differentInputs() {
        let h1 = fnv1a32("a")
        let h2 = fnv1a32("b")
        #expect(h1 != h2)
    }

    @Test("hash is deterministic across calls")
    func deterministic() {
        let h1 = fnv1a32("user123|checkout")
        let h2 = fnv1a32("user123|checkout")
        #expect(h1 == h2)
    }
}

// MARK: - JSONFileFeatureFlagSource Tests

@Suite("JSONFileFeatureFlagSource")
struct JSONFileSourceTests {
    @Test("parses JSON file")
    func parseJSON() async throws {
        let json = Data("""
        {
            "new_onboarding": true,
            "max_retries": 5,
            "api_endpoint": "https://api.example.com"
        }
        """.utf8)

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_flags_\(UUID().uuidString).json")
        try json.write(to: fileURL)

        // Create a bundle pointing at the temp directory
        let source = try JSONFileFeatureFlagSource(
            fileName: fileURL.lastPathComponent,
            bundle: #require(Bundle(url: tempDir))
        )

        let value = await source.value(for: FeatureFlagKey("new_onboarding"))
        #expect(value == .bool(true))

        let count = await source.value(for: FeatureFlagKey("max_retries"))
        #expect(count == .int(5))

        let endpoint = await source.value(for: FeatureFlagKey("api_endpoint"))
        #expect(endpoint == .string("https://api.example.com"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - ConfigurationFeatureFlagSource Tests

@Suite("ConfigurationFeatureFlagSource")
struct ConfigurationFeatureFlagSourceTests {
    @Test("reads bool from AnvilConfiguration")
    func readBool() async {
        let config = AnvilConfiguration()
        await config.set("feature_a", value: true)
        let source = ConfigurationFeatureFlagSource(configuration: config)

        let value = await source.value(for: FeatureFlagKey("feature_a"))
        #expect(value == .bool(true))
    }

    @Test("reads int from AnvilConfiguration")
    func readInt() async {
        let config = AnvilConfiguration()
        await config.set("count", value: 42)
        let source = ConfigurationFeatureFlagSource(configuration: config)

        let value = await source.value(for: FeatureFlagKey("count"))
        #expect(value == .int(42))
    }

    @Test("reads double from AnvilConfiguration")
    func readDouble() async {
        let config = AnvilConfiguration()
        await config.set("rate", value: 3.14)
        let source = ConfigurationFeatureFlagSource(configuration: config)

        let value = await source.value(for: FeatureFlagKey("rate"))
        #expect(value == .double(3.14))
    }

    @Test("reads string from AnvilConfiguration")
    func readString() async {
        let config = AnvilConfiguration()
        await config.set("endpoint", value: "https://api.example.com")
        let source = ConfigurationFeatureFlagSource(configuration: config)

        let value = await source.value(for: FeatureFlagKey("endpoint"))
        #expect(value == .string("https://api.example.com"))
    }

    @Test("returns nil for missing key")
    func missingKey() async {
        let config = AnvilConfiguration()
        let source = ConfigurationFeatureFlagSource(configuration: config)

        let value = await source.value(for: FeatureFlagKey("missing"))
        #expect(value == nil)
    }

    @Test("allFlags returns all stored flags")
    func allFlags() async {
        let config = AnvilConfiguration()
        await config.set("feature_a", value: true)
        await config.set("count", value: 10)
        let source = ConfigurationFeatureFlagSource(configuration: config)

        let flags = await source.allFlags()
        #expect(flags.count == 2)
        #expect(flags[FeatureFlagKey("feature_a")] == .bool(true))
        #expect(flags[FeatureFlagKey("count")] == .int(10))
    }

    @Test("FeatureFlagSystem with configuration source resolves flags")
    func systemWithConfiguration() async {
        let config = AnvilConfiguration()
        await config.set("feature_a", value: true)
        await config.set("count", value: 10)

        let system = FeatureFlagSystem(configuration: config)

        #expect(await system.isEnabled(FeatureFlagKey("feature_a")) == true)
        #expect(await system.value(for: FeatureFlagKey("count")) == .int(10))
    }

    @Test("configuration source is lowest priority")
    func configurationPriority() async {
        let config = AnvilConfiguration()
        await config.set("feature_a", value: false)

        let system = FeatureFlagSystem(
            sources: [
                InMemoryFeatureFlagSource([FeatureFlagKey("feature_a"): .bool(true)])
            ],
            configuration: config
        )

        // In-memory source should win because it is first
        let value = await system.value(for: FeatureFlagKey("feature_a"))
        #expect(value == .bool(true))
    }
}

// MARK: - Integration Tests

@Suite("Integration")
struct IntegrationTests {
    @Test("full flow: configure, read, override")
    func fullFlow() async {
        await FeatureFlags.configure(sources: [
            InMemoryFeatureFlagSource([
                FeatureFlagKey("feature_a"): .bool(true),
                FeatureFlagKey("count"): .int(10),
                FeatureFlagKey("rate"): .double(0.5),
                FeatureFlagKey("endpoint"): .string("https://api.example.com")
            ])
        ])

        #expect(await FeatureFlags.isEnabled(FeatureFlagKey("feature_a")) == true)
        #expect(await FeatureFlags.value(FeatureFlagKey("count"), as: Int.self, default: 0) == 10)
        #expect(await FeatureFlags.value(FeatureFlagKey("rate"), as: Double.self, default: 0.0) == 0.5)
        #expect(await FeatureFlags
            .value(FeatureFlagKey("endpoint"), as: String.self, default: "") == "https://api.example.com")
        #expect(await FeatureFlags.value(FeatureFlagKey("missing"), as: Int.self, default: 99) == 99)
    }

    @Test("test injection with multiple flags")
    func injectionMultiple() async {
        let testSystem = FeatureFlagSystem(sources: [
            InMemoryFeatureFlagSource([
                FeatureFlagKey("flag1"): .bool(true),
                FeatureFlagKey("flag2"): .int(42)
            ])
        ])

        await FeatureFlags.withSystem(testSystem) {
            #expect(await FeatureFlags.isEnabled(FeatureFlagKey("flag1")) == true)
            #expect(await FeatureFlags.value(FeatureFlagKey("flag2"), as: Int.self, default: 0) == 42)
        }
    }
}
