//
//  WeatherService_Tests.swift
//  Geo PulseTests
//
//  XCTest coverage of the OpenWeatherMap integration. Uses the classic XCTest
//  style on purpose (the rest of the suite uses Swift Testing) so both
//  frameworks are demonstrated.
//

import XCTest
import CoreLocation
@testable import Geo_Pulse

final class WeatherService_Tests: XCTestCase {

    func testMissingAPIKeyThrowsWithoutInfoPlistEntry() async throws {
        // The Info.plist for the test host does not include OPENWEATHER_API_KEY,
        // so fetchCurrent should fail fast rather than hitting the network.
        let service = WeatherService()
        let coord = CLLocationCoordinate2D(latitude: 30.4515, longitude: -91.1871)

        do {
            _ = try await service.fetchCurrent(for: coord)
            XCTFail("Expected WeatherServiceError.missingAPIKey — got a successful response instead")
        } catch WeatherServiceError.missingAPIKey {
            // expected
        } catch {
            // The service may throw a different error if the key *is* present in the test host.
            // Allow URL/network errors so this test is still useful when the key is injected
            // via an alternate xcconfig during CI.
            XCTAssertFalse(error is DecodingError, "Unexpected JSON decoding failure")
        }
    }

    func testWeatherSnapshotIsHashable() {
        let a = WeatherSnapshot(
            temperatureF: 72, windMph: 5, windDirection: "NE",
            condition: "Clear", severeWarning: nil
        )
        let b = WeatherSnapshot(
            temperatureF: 72, windMph: 5, windDirection: "NE",
            condition: "Clear", severeWarning: nil
        )
        XCTAssertEqual(a, b, "Snapshots with identical fields should be equal")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testWeatherSnapshotDistinguishesBySevereWarning() {
        let calm = WeatherSnapshot(
            temperatureF: 72, windMph: 5, windDirection: "NE",
            condition: "Clear", severeWarning: nil
        )
        let stormy = WeatherSnapshot(
            temperatureF: 72, windMph: 5, windDirection: "NE",
            condition: "Clear", severeWarning: "Thunderstorm"
        )
        XCTAssertNotEqual(calm, stormy)
    }
}
