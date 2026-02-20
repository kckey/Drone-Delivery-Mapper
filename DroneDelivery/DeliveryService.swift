import Foundation
import CoreLocation

/// Simulates a drone flight and reports ETA & feasibility.
final class DeliveryService {

    /// Drone speed – 50 km/h = 13.8889 m/s
    private let speed: Double = 13.8889

    /// Starts the “flight”.
    ///
    /// - Parameters:
    ///   - from:   starting coordinate (store)
    ///   - to:     destination (user’s home)
    ///   - progressHandler: called every second with ETA (seconds) and a feasibility flag.
    ///   - completion: called when flight ends or is aborted.
    func startFlight(from: CLLocationCoordinate2D,
                     to: CLLocationCoordinate2D,
                     progressHandler: @escaping (_ eta: TimeInterval, _ feasible: Bool, _ progress: Double) -> Void,
                     completion: @escaping (_ delivered: Bool) -> Void) {

        let totalDistance = haversineDistance(from, to)

        var elapsed: TimeInterval = 0
        let interval: TimeInterval = 1       // update every second
        var hasFinished = false

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            guard !hasFinished else {
                timer.invalidate()
                return
            }

            elapsed += interval
            let remainingDistance = max(totalDistance - self.speed * elapsed, 0)
            let progress = min(1, (self.speed * elapsed) / max(totalDistance, 0.1))
            if remainingDistance <= 0 {
                hasFinished = true
                timer.invalidate()
                DispatchQueue.main.async {
                    progressHandler(0, true, 1)
                    completion(true)
                }
                return
            }

            let eta = remainingDistance / self.speed

            WeatherService.fetchWeather(at: to) { result in
                let feasible: Bool
                switch result {
                case .success(let weather):
                    feasible = weather.wind.speed <= 10 && weather.main.temp >= -5
                case .failure:
                    feasible = false
                }

                DispatchQueue.main.async {
                    progressHandler(eta, feasible, progress)
                    if (!feasible || eta <= 0) && !hasFinished {
                        hasFinished = true
                        timer.invalidate()
                        completion(feasible)
                    }
                }
            }
        }
    }

    /// Haversine distance (meters) between two coordinates.
    private func haversineDistance(_ a: CLLocationCoordinate2D,
                                   _ b: CLLocationCoordinate2D) -> Double {
        let R = 6_371_000.0   // Earth radius in meters
        let dLat = (b.latitude - a.latitude).degreesToRadians
        let dLon = (b.longitude - a.longitude).degreesToRadians
        let lat1 = a.latitude.degreesToRadians
        let lat2 = b.latitude.degreesToRadians

        let h = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return 2 * R * asin(sqrt(h))
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
}
