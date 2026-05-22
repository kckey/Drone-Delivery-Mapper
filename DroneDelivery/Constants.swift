import Foundation
import CoreLocation

struct Constants {
    static let openWeatherKey = "YOUR_OPENWEATHERMAP_KEY"
    static let droneSpeedMetersPerSecond = 18.0
    static let positionUpdateInterval = 0.15
    static let maxSafeWindMetersPerSecond = 10.0
    static let minimumSafeTemperatureCelsius = -5.0
    
    // Store location – “Tech Hub”
    static let storeCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
}
