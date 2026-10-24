//
//  PureLogicTests.swift
//  Geo PulseTests
//
//  Deterministic Swift Testing coverage of the pure-logic modules extracted
//  from `LocationService`, `MotionService`, and `HazardClassifier`. These
//  tests do not touch Core Location, Core Motion, or Vision — the hardware
//  callbacks live in thin wrappers that call into these pure modules.
//

import Testing
import Foundation
import CoreLocation
@testable import Geo_Pulse

// MARK: - GeofenceSelector

@MainActor
@Suite("GeofenceSelector")
struct GeofenceSelectorTests {

    private func makeSites(_ count: Int, latStart: Double = 30.0, lonStart: Double = -91.0) -> [Site] {
        (0..<count).map {
            Site(
                name: "Site \($0)",
                latitude: latStart + Double($0) * 0.01,
                longitude: lonStart,
                geofenceRadius: 150
            )
        }
    }

    @Test("Returns empty when limit is zero")
    func zeroLimit() {
        let picked = GeofenceSelector.pickNearest(makeSites(5), to: nil, limit: 0)
        #expect(picked.isEmpty)
    }

    @Test("Returns insertion order when origin is nil")
    func fallbackOrderWithoutOrigin() {
        let sites = makeSites(5)
        let picked = GeofenceSelector.pickNearest(sites, to: nil, limit: 3)
        #expect(picked.map(\.name) == ["Site 0", "Site 1", "Site 2"])
    }

    @Test("Sorts strictly by distance from origin when provided")
    func sortsByDistance() {
        let sites = [
            Site(name: "Far",  latitude: 32.0, longitude: -91.0),
            Site(name: "Near", latitude: 30.1, longitude: -91.0),
            Site(name: "Mid",  latitude: 30.5, longitude: -91.0)
        ]
        let origin = CLLocation(latitude: 30.0, longitude: -91.0)
        let picked = GeofenceSelector.pickNearest(sites, to: origin, limit: 3)
        #expect(picked.map(\.name) == ["Near", "Mid", "Far"])
    }

    @Test("Caps at 20 regardless of requested limit")
    func capsAtIOSLimit() {
        let sites = makeSites(50)
        let picked = GeofenceSelector.pickNearest(sites, to: nil, limit: 100)
        #expect(picked.count == GeofenceSelector.maxMonitoredRegions)
    }

    @Test("Respects a smaller user-supplied limit")
    func respectsSmallLimit() {
        let picked = GeofenceSelector.pickNearest(makeSites(10), to: nil, limit: 4)
        #expect(picked.count == 4)
    }

    @Test("Handles empty input")
    func emptyInput() {
        #expect(GeofenceSelector.pickNearest([], to: nil).isEmpty)
    }
}

// MARK: - FallDetector

@MainActor
@Suite("FallDetector")
struct FallDetectorTests {

    @Test("A single impact alone does not fire")
    func impactAloneDoesNotFire() {
        let detector = FallDetector()
        let fired = detector.ingest(sample: .init(
            accelerationMagnitude: 4.0,
            rotationMagnitude: 0.0,
            timestamp: Date(timeIntervalSince1970: 0)
        ))
        #expect(!fired)
    }

    @Test("Impact followed by stillness within the window fires")
    func impactThenStillnessFires() {
        let detector = FallDetector()
        let now = Date(timeIntervalSince1970: 100)
        _ = detector.ingest(sample: .init(accelerationMagnitude: 4.0, rotationMagnitude: 0.0, timestamp: now))
        let fired = detector.ingest(sample: .init(
            accelerationMagnitude: 0.1,
            rotationMagnitude: 0.05,
            timestamp: now.addingTimeInterval(1.5)
        ))
        #expect(fired)
    }

    @Test("Impact then rotation above threshold does NOT fire (user still moving)")
    func rotationBlocksFire() {
        let detector = FallDetector()
        let now = Date(timeIntervalSince1970: 100)
        _ = detector.ingest(sample: .init(accelerationMagnitude: 4.0, rotationMagnitude: 0.0, timestamp: now))
        let fired = detector.ingest(sample: .init(
            accelerationMagnitude: 0.1,
            rotationMagnitude: 1.5,  // moving — not still
            timestamp: now.addingTimeInterval(1.5)
        ))
        #expect(!fired)
    }

    @Test("Stillness arriving too soon (< 1s) is ignored")
    func stillnessTooSoonIgnored() {
        let detector = FallDetector()
        let now = Date(timeIntervalSince1970: 100)
        _ = detector.ingest(sample: .init(accelerationMagnitude: 4.0, rotationMagnitude: 0.0, timestamp: now))
        let fired = detector.ingest(sample: .init(
            accelerationMagnitude: 0.1,
            rotationMagnitude: 0.0,
            timestamp: now.addingTimeInterval(0.3)
        ))
        #expect(!fired)
    }

    @Test("Stillness arriving too late (> 3s) is ignored and state resets")
    func stillnessTooLateIgnored() {
        let detector = FallDetector()
        let now = Date(timeIntervalSince1970: 100)
        _ = detector.ingest(sample: .init(accelerationMagnitude: 4.0, rotationMagnitude: 0.0, timestamp: now))
        let fired = detector.ingest(sample: .init(
            accelerationMagnitude: 0.1,
            rotationMagnitude: 0.0,
            timestamp: now.addingTimeInterval(5.0)
        ))
        #expect(!fired)
        #expect(detector.lastImpactAt == nil)
    }

    @Test("After firing, state resets so a new fall can be detected later")
    func stateResetsAfterFire() {
        let detector = FallDetector()
        let t0 = Date(timeIntervalSince1970: 100)
        _ = detector.ingest(sample: .init(accelerationMagnitude: 4.0, rotationMagnitude: 0.0, timestamp: t0))
        let firedOnce = detector.ingest(sample: .init(
            accelerationMagnitude: 0.1, rotationMagnitude: 0.0,
            timestamp: t0.addingTimeInterval(1.2)
        ))
        #expect(firedOnce)

        // Another impact + stillness later should fire again
        let t1 = t0.addingTimeInterval(60)
        _ = detector.ingest(sample: .init(accelerationMagnitude: 4.0, rotationMagnitude: 0.0, timestamp: t1))
        let firedTwice = detector.ingest(sample: .init(
            accelerationMagnitude: 0.1, rotationMagnitude: 0.0,
            timestamp: t1.addingTimeInterval(1.2)
        ))
        #expect(firedTwice)
    }

    @Test("Sub-threshold acceleration never arms the detector")
    func subThresholdNeverArms() {
        let detector = FallDetector()
        let fired = detector.ingest(sample: .init(
            accelerationMagnitude: 2.9,
            rotationMagnitude: 0.0,
            timestamp: Date()
        ))
        #expect(!fired)
        #expect(detector.lastImpactAt == nil)
    }
}

// MARK: - HazardMapper

@MainActor
@Suite("HazardMapper")
struct HazardMapperTests {

    @Test("Maps a rust observation to Surface corrosion")
    func mapsRust() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "oxidized_iron", confidence: 0.9)
        ])
        #expect(result.label == "Surface corrosion")
    }

    @Test("Maps a crack observation to Structural crack")
    func mapsCrack() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "hairline_crack_in_concrete", confidence: 0.8)
        ])
        #expect(result.label == "Structural crack")
    }

    @Test("Maps an exposed-wire observation to Exposed wiring")
    func mapsExposedWiring() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "frayed_electrical_wire", confidence: 0.72)
        ])
        #expect(result.label == "Exposed wiring")
    }

    @Test("Takes the FIRST matching observation, not the strongest")
    func firstMatchWins() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "wire_bundle", confidence: 0.6),       // Exposed wiring
            .init(identifier: "rust_patch",  confidence: 0.95)       // would be Surface corrosion
        ])
        #expect(result.label == "Exposed wiring")
    }

    @Test("Returns the fallback label when no observation matches")
    func fallbackWhenNothingMatches() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "cat", confidence: 0.9),
            .init(identifier: "sofa", confidence: 0.8)
        ])
        #expect(result.label == HazardMapper.fallbackLabel)
        #expect(result.confidence == HazardMapper.fallbackConfidence)
    }

    @Test("Empty observations report unavailable analysis")
    func emptyObservations() {
        let result = HazardMapper.classify(observations: [])
        #expect(result.label == HazardMapper.unavailableLabel)
        #expect(result.rawTopIdentifier == nil)
    }

    @Test("Preserves low classifier confidence")
    func clampsLowConfidence() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "rust", confidence: 0.1)
        ])
        #expect(result.confidence == 0.1)
    }

    @Test("Preserves high classifier confidence")
    func clampsHighConfidence() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "rust", confidence: 0.9999)
        ])
        #expect(result.confidence == 0.9999)
    }

    @Test("Preserves the raw top identifier when a match is found")
    func preservesRawIdentifier() {
        let result = HazardMapper.classify(observations: [
            .init(identifier: "steel_pipework", confidence: 0.72)
        ])
        #expect(result.rawTopIdentifier == "steel_pipework")
        #expect(result.label == "Structural wear")
    }
}

@MainActor
@Suite("Detector boundaries")
struct DetectorBoundaryTests {
    @Test(arguments: [1.0, 3.0])
    func includesWindowBoundary(seconds: Double) {
        let detector = FallDetector()
        let start = Date(timeIntervalSince1970: 100)
        detector.ingest(sample: .init(accelerationMagnitude: 4, rotationMagnitude: 0, timestamp: start))
        #expect(detector.ingest(sample: .init(accelerationMagnitude: 0, rotationMagnitude: 0, timestamp: start.addingTimeInterval(seconds))))
        #expect(!detector.ingest(sample: .init(accelerationMagnitude: 0, rotationMagnitude: 0, timestamp: start.addingTimeInterval(seconds))))
    }
    @Test func exactImpactThresholdDoesNotArm() {
        let detector = FallDetector()
        detector.ingest(sample: .init(accelerationMagnitude: 3, rotationMagnitude: 0, timestamp: .now))
        #expect(detector.lastImpactAt == nil)
    }
    @Test func resetCancelsPendingImpact() {
        let detector = FallDetector()
        let start = Date(timeIntervalSince1970: 100)
        detector.ingest(sample: .init(accelerationMagnitude: 4, rotationMagnitude: 0, timestamp: start))
        detector.reset()
        #expect(!detector.ingest(sample: .init(accelerationMagnitude: 0, rotationMagnitude: 0, timestamp: start.addingTimeInterval(2))))
    }
    @Test func negativeLimitSelectsNothing() {
        #expect(GeofenceSelector.pickNearest(SampleData.sites, to: nil, limit: -1).isEmpty)
    }
}
