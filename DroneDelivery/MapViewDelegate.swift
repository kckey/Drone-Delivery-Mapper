import UIKit
import MapKit

/// Handles all Map‑related delegate work.
final class MapViewDelegate: NSObject, MKMapViewDelegate {

    // MARK: Render route polyline
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }

        let renderer = MKPolylineRenderer(polyline: line)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 3
        renderer.lineCap = .round
        renderer.lineJoin = .round
        return renderer
    }

    // MARK: Annotation styling
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }

        let identifier = "Marker"
        let view: MKMarkerAnnotationView
        if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
            dequeued.annotation = annotation
            view = dequeued
        } else {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        }

        let title = annotation.title ?? ""
        switch title {
        case "Store":
            view.markerTintColor = .systemGreen
            view.glyphImage = UIImage(systemName: "shippingbox.fill")
        case "Destination":
            view.markerTintColor = .systemBlue
            view.glyphImage = UIImage(systemName: "mappin.circle.fill")
        case "Drone":
            view.markerTintColor = .systemOrange
            view.glyphImage = UIImage(systemName: "paperplane")
        default:
            view.markerTintColor = .systemGray
            view.glyphImage = nil
        }
        view.displayPriority = .required
        view.canShowCallout = true
        return view
    }
}
