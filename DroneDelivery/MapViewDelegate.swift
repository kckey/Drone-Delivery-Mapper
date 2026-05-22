import UIKit
import MapKit

/// Handles all Map‑related delegate work.
final class MapViewDelegate: NSObject, MKMapViewDelegate {

    // MARK: Render route polyline
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }

        let renderer = MKPolylineRenderer(polyline: line)
        renderer.strokeColor = UIColor(red: 0.68, green: 0.39, blue: 0.18, alpha: 1)
        renderer.lineWidth = 4
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
        case "Dispatch Hub":
            view.markerTintColor = UIColor(red: 0.39, green: 0.55, blue: 0.35, alpha: 1)
            view.glyphImage = UIImage(systemName: "shippingbox.fill")
        case "Drop Zone":
            view.markerTintColor = UIColor(red: 0.68, green: 0.39, blue: 0.18, alpha: 1)
            view.glyphImage = UIImage(systemName: "mappin.circle.fill")
        case "Drone":
            view.markerTintColor = UIColor(red: 0.84, green: 0.52, blue: 0.22, alpha: 1)
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
