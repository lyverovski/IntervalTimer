import Foundation
import Testing
@testable import IntervalTimer

@MainActor
struct SettingsStoreTests {
	let defaults: UserDefaults

	init() {
		let suite = "SettingsStoreTests-\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: suite)!
		defaults.removePersistentDomain(forName: suite)
	}

	@Test func shouldUseDefaultConfigOnFirstLaunch() {
		let store = SettingsStore(defaults: defaults)
		#expect(store.config == .default)
	}

	@Test func shouldRememberLastUsedConfigAcrossLaunches() {
		let config = WorkoutConfig(warmUp: 120, work: 45, rest: 15, intervals: 12)
		SettingsStore(defaults: defaults).config = config
		#expect(SettingsStore(defaults: defaults).config == config)
	}

	@Test func shouldFallBackToDefaultWhenStoredConfigIsCorrupt() {
		defaults.set(Data("not json".utf8), forKey: SettingsStore.configKey)
		#expect(SettingsStore(defaults: defaults).config == .default)
	}

	@Test func shouldClampOutOfRangeStoredConfig() throws {
		let bad = WorkoutConfig(warmUp: 5000, work: 1, rest: 1000, intervals: 500)
		defaults.set(try JSONEncoder().encode(bad), forKey: SettingsStore.configKey)
		#expect(SettingsStore(defaults: defaults).config == bad.clamped())
	}

	@Test func shouldUseDefaultToneForEachCueOnFirstLaunch() {
		let store = SettingsStore(defaults: defaults)
		for kind in CueKind.allCases {
			#expect(store.tone(for: kind) == ToneCatalog.defaultTone(for: kind))
		}
	}

	@Test func shouldRememberSelectedTone() throws {
		let tone = try #require(ToneCatalog.tones(for: .intervalEnd).last)
		SettingsStore(defaults: defaults).setTone(tone, for: .intervalEnd)
		#expect(SettingsStore(defaults: defaults).tone(for: .intervalEnd) == tone)
	}

	@Test func shouldIgnoreStoredToneNotInCatalog() {
		defaults.set("deleted-tone", forKey: SettingsStore.toneKey(for: .finish))
		#expect(SettingsStore(defaults: defaults).tone(for: .finish) == ToneCatalog.defaultTone(for: .finish))
	}

	@Test func shouldRejectToneThatDoesNotBelongToCue() throws {
		let store = SettingsStore(defaults: defaults)
		let beep = try #require(ToneCatalog.tones(for: .countdown).first)
		store.setTone(beep, for: .finish)
		#expect(store.tone(for: .finish) == ToneCatalog.defaultTone(for: .finish))
	}
}

@MainActor
struct ToneCatalogTests {

	@Test func shouldOfferAtLeastTwoTonesForEveryCue() {
		for kind in CueKind.allCases {
			#expect(ToneCatalog.tones(for: kind).count >= 2)
		}
	}

	@Test func shouldShareBingTonesBetweenIntervalStartAndEnd() {
		#expect(ToneCatalog.tones(for: .intervalStart) == ToneCatalog.tones(for: .intervalEnd))
	}

	@Test func shouldBundleASoundFileForEveryTone() {
		let all = CueKind.allCases.flatMap(ToneCatalog.tones(for:))
		for tone in all {
			#expect(Bundle.main.url(forResource: tone.id, withExtension: "wav") != nil, "Missing \(tone.id).wav")
		}
		#expect(Bundle.main.url(forResource: ToneCatalog.silenceFile, withExtension: "wav") != nil)
	}
}
