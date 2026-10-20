import Foundation
import CoreLocation

struct WeatherService {
    static let shared = WeatherService()

    private let apiKey: String = "3aa1af71aeed19c3816a75659308635b"
    private let session: URLSession = .shared

    func fetchCurrent(for coordinate: CLLocationCoordinate2D) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial")
        ]

        let (data, _) = try await session.data(from: components.url!)
        let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

        return WeatherSnapshot(
            temperatureF: Int(decoded.main.temp.rounded()),
            windMph: Int(decoded.wind.speed.rounded()),
            windDirection: directionLabel(from: decoded.wind.deg),
            condition: decoded.weather.first?.main ?? "Clear",
            severeWarning: decoded.weather.first.flatMap { entry in
                entry.id < 800 ? entry.description.capitalized : nil
            }
        )
    }

    private func directionLabel(from degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(((degrees + 22.5) / 45).truncatingRemainder(dividingBy: 8))
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
