import Foundation
import CoreLocation

struct WeatherResponse: Decodable {
    struct Main: Decodable { let temp: Double }
    struct Wind: Decodable { let speed: Double }
    let main: Main
    let wind: Wind
}

enum WeatherServiceError: Error {
    case invalidKey
    case invalidURL
    case missingData
}

class WeatherService {

    static func fetchWeather(at coordinate: CLLocationCoordinate2D,
                             completion: @escaping (Result<WeatherResponse, Error>) -> Void) {

        // If no key was supplied provide a friendly fallback so the demo still works.
        if Constants.openWeatherKey.isEmpty || Constants.openWeatherKey == "YOUR_OPENWEATHERMAP_KEY" {
            let mock = WeatherResponse(main: .init(temp: 18),
                                       wind: .init(speed: 6))
            DispatchQueue.main.async {
                completion(.success(mock))
            }
            return
        }

        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "appid", value: Constants.openWeatherKey)
        ]

        guard let url = components?.url else {
            DispatchQueue.main.async {
                completion(.failure(WeatherServiceError.invalidURL))
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(WeatherServiceError.missingData))
                }
                return
            }

            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
