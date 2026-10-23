//
//  WeatherService_Tests.swift
//  Geo PulseTests
//
//  Swift Testing coverage of the OpenWeatherMap integration. A URLProtocol
//  stub lets us exercise the real request/decode path without hitting the
//  network, satisfying the "API parsing" test category named in the proposal.
//

import Testing
import Foundation
import CoreLocation
@testable import Geo_Pulse

// MARK: - URLProtocol stub

private final class WeatherURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let latitude = components.queryItems?.first { $0.name == "lat" }?.value
        let status = latitude == "1.0" ? 401 : 200
        let body = latitude == "2.0" ? "invalid JSON" : """
        {"main":{"temp":72.6},"wind":{"speed":5.4,"deg":45},
         "weather":[{"id":211,"main":"Thunderstorm","description":"thunderstorm"}]}
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func stubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WeatherURLProtocol.self]
    return URLSession(configuration: configuration)
}

// MARK: - Suites

@Suite("WeatherService — key handling")
struct WeatherServiceKeyTests {

    @Test("Missing API key throws .missingAPIKey without touching the network")
    func missingAPIKeyThrows() async {
        let service = WeatherService(apiKey: nil)
        let coord = CLLocationCoordinate2D(latitude: 30.4515, longitude: -91.1871)
        do {
            _ = try await service.fetchCurrent(for: coord)
            Issue.record("Expected missingAPIKey, call succeeded instead")
        } catch WeatherServiceError.missingAPIKey {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Blank/whitespace API key is treated as missing")
    func whitespaceKeyTreatedAsMissing() async {
        let service = WeatherService(apiKey: "   ")
        do {
            _ = try await service.fetchCurrent(for: .init(latitude: 0, longitude: 0))
            Issue.record("Expected missingAPIKey for whitespace key")
        } catch WeatherServiceError.missingAPIKey {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("WeatherService — response parsing")
struct WeatherServiceParseTests {

    @Test("Parses a well-formed response into a WeatherSnapshot")
    func parsesWellFormedResponse() async throws {
        let session = stubSession()
        defer { session.invalidateAndCancel() }
        let service = WeatherService(session: session, apiKey: "test-key")
        let snapshot = try await service.fetchCurrent(for: .init(latitude: 0, longitude: 0))

        #expect(snapshot.temperatureF == 73)
        #expect(snapshot.windMph == 5)
        #expect(snapshot.windDirection == "NE")
        #expect(snapshot.condition == "Thunderstorm")
        #expect(snapshot.severeWarning == "Thunderstorm")
    }

    @Test("A non-2xx HTTP status is surfaced as .badResponse")
    func httpErrorThrowsBadResponse() async {
        let session = stubSession()
        defer { session.invalidateAndCancel() }
        let service = WeatherService(session: session, apiKey: "test-key")
        do {
            _ = try await service.fetchCurrent(for: .init(latitude: 1, longitude: 0))
            Issue.record("Expected badResponse for 401")
        } catch WeatherServiceError.badResponse {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Malformed JSON surfaces as a DecodingError")
    func malformedJSONThrowsDecoding() async {
        let session = stubSession()
        defer { session.invalidateAndCancel() }
        let service = WeatherService(session: session, apiKey: "test-key")
        do {
            _ = try await service.fetchCurrent(for: .init(latitude: 2, longitude: 0))
            Issue.record("Expected DecodingError")
        } catch is DecodingError {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("WeatherSnapshot — equality")
struct WeatherSnapshotTests {

    @Test("Snapshots with identical fields are equal")
    func equalWhenFieldsMatch() {
        let a = WeatherSnapshot(temperatureF: 72, windMph: 5, windDirection: "NE",
                                condition: "Clear", severeWarning: nil)
        let b = WeatherSnapshot(temperatureF: 72, windMph: 5, windDirection: "NE",
                                condition: "Clear", severeWarning: nil)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Severe warning distinguishes two otherwise identical snapshots")
    func severeWarningMatters() {
        let calm = WeatherSnapshot(temperatureF: 72, windMph: 5, windDirection: "NE",
                                   condition: "Clear", severeWarning: nil)
        let stormy = WeatherSnapshot(temperatureF: 72, windMph: 5, windDirection: "NE",
                                     condition: "Clear", severeWarning: "Thunderstorm")
        #expect(calm != stormy)
    }
}
