import Foundation
import MapKit

class Drone {
    enum Status {
        case idle, flying, delivered, failed
    }
    
    var status: Status = .idle
    
    /// Current position – will be animated on the map.
    var coordinate: CLLocationCoordinate2D
    
    init(start: CLLocationCoordinate2D) {
        self.coordinate = start
    }
}
