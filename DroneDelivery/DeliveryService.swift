import Foundation
import CoreLocation

/// Simulates a drone flight and reports ETA, feasibility, and progress.
final class DeliveryService {

    private var activeTimer: Timer?

    func startFlight(from: CLLocationCoordinate2D,
                     to: CLLocationCoordinate2D,
                     progressHandler: @escaping (_ eta: TimeInterval, _ feasible: Bool, _ progress: Double) -> Void,
                     completion: @escaping (_ delivered: Bool) -> Void) {

        activeTimer?.invalidate()

        let totalDistance = Self.distanceMeters(from: from, to: to)
        let totalDuration = max(totalDistance / Constants.droneSpeedMetersPerSecond, 1)
        let startedAt = Date()

        WeatherService.fetchWeather(at: to) { [weak self] result in
            guard let self else { return }

            let feasible: Bool
            switch result {
            case .success(let weather):
                feasible = weather.wind.speed <= Constants.maxSafeWindMetersPerSecond &&
                    weather.main.temp >= Constants.minimumSafeTemperatureCelsius
            case .failure:
                feasible = false
            }

            guard feasible else {
                progressHandler(totalDuration, false, 0)
                completion(false)
                return
            }

            self.activeTimer = Timer.scheduledTimer(withTimeInterval: Constants.positionUpdateInterval, repeats: true) { [weak self] timer in
                guard self != nil else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                let progress = min(elapsed / totalDuration, 1)
                let eta = max(totalDuration - elapsed, 0)
                progressHandler(eta, true, progress)

                if progress >= 1 {
                    timer.invalidate()
                    completion(true)
                }
            }
        }
    }

    func cancel() {
        activeTimer?.invalidate()
        activeTimer = nil
    }

    static func distanceMeters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0
        let deltaLatitude = (b.latitude - a.latitude).degreesToRadians
        let deltaLongitude = (b.longitude - a.longitude).degreesToRadians
        let latitudeA = a.latitude.degreesToRadians
        let latitudeB = b.latitude.degreesToRadians

        let haversine = sin(deltaLatitude / 2) * sin(deltaLatitude / 2) +
            cos(latitudeA) * cos(latitudeB) *
            sin(deltaLongitude / 2) * sin(deltaLongitude / 2)

        return 2 * earthRadius * asin(sqrt(haversine))
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
}
