import Foundation
import CoreLocation

enum WeatherServiceError: Error {
    case missingAPIKey
    case badResponse
}

struct WeatherService {
    static let shared = WeatherService()

    private let session: URLSession
    private let apiKey: String?

    init(
        session: URLSession = .shared,
        apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "OPENWEATHER_API_KEY") as? String
    ) {
        self.session = session
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = (trimmed?.isEmpty == false && trimmed?.hasPrefix("$(") == false) ? trimmed : nil
    }

    func fetchCurrent(for coordinate: CLLocationCoordinate2D) async throws -> WeatherSnapshot {
        guard let apiKey else { throw WeatherServiceError.missingAPIKey }

        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial")
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherServiceError.badResponse
        }
        let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

        guard let temperature = Int(exactly: decoded.main.temp.rounded()),
              let windSpeed = Int(exactly: decoded.wind.speed.rounded()), windSpeed >= 0,
              decoded.wind.deg.isFinite else { throw WeatherServiceError.badResponse }
        return WeatherSnapshot(
            temperatureF: temperature,
            windMph: windSpeed,
            windDirection: directionLabel(from: decoded.wind.deg),
            condition: decoded.weather.first?.main ?? "Unavailable",
            severeWarning: decoded.weather.first.flatMap { entry in
                // App advisory policy, not an official severe-weather alert feed.
                (200..<300).contains(entry.id) || entry.id == 781 ? entry.description.capitalized : nil
            }
        )
    }

    private func directionLabel(from degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int(((normalized + 22.5) / 45).truncatingRemainder(dividingBy: 8))
        return directions[max(0, min(directions.count - 1, index))]
    }
}

private struct OpenWeatherResponse: Decodable {
    struct Main: Decodable { let temp: Double }
    struct Wind: Decodable { let speed: Double; let deg: Double }
    struct Weather: Decodable { let id: Int; let main: String; let description: String }

    let main: Main
    let wind: Wind
    let weather: [Weather]
}
