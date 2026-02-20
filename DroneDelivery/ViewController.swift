//
//  ViewController.swift
//  DroneDeliveryDemo
//

import UIKit
import MapKit

final class ViewController: UIViewController {

    // MARK: UI Elements
    private let map = MKMapView()
    private let cardView = UIView()

    // Modern card background + chrome
    private let cardBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let cardContentView = UIView()
    private let cardHandle = UIView()

    private let instructionLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let returnButton = UIButton(type: .system)
    private let zoomStack = UIStackView()

    // MARK: Managers & State
    private let locationManager = CLLocationManager()
    private var drone = Drone(start: Constants.storeCoordinate)
    private let deliveryService = DeliveryService()
    private var destination: CLLocationCoordinate2D?
    private let mapDelegate = MapViewDelegate()
    private var droneAnnotation: MKPointAnnotation?
    private var flightStartCoordinate: CLLocationCoordinate2D?

    private lazy var etaFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    // MARK: Life-cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        map.delegate = mapDelegate
        addStoreAnnotation()
        requestLocationPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the card padded above the device’s home indicator.
        let bottomInset = max(view.safeAreaInsets.bottom, 12)
        cardView.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: bottomInset + 10, right: 18)

        // keep shadow path up to date for smooth scrolling/perf
        cardView.layer.shadowPath = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: 24).cgPath
    }

    // MARK: UI helpers ------------------------------------------------------
    private func setupUI() {
        view.backgroundColor = .systemBackground
        map.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(map)
        view.addSubview(cardView)

        if #available(iOS 16.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            map.preferredConfiguration = config
        } else {
            map.mapType = .mutedStandard
        }
        map.overrideUserInterfaceStyle = .dark
        map.showsCompass = false
        map.showsScale = false
        map.pointOfInterestFilter = .excludingAll
        map.isRotateEnabled = false

        // --- Modern card styling (material + subtle border + floating shadow) ---
        cardView.backgroundColor = .clear
        cardView.layer.cornerRadius = 24
        cardView.layer.cornerCurve = .continuous
        cardView.layer.masksToBounds = false

        // Floating shadow
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.22
        cardView.layer.shadowRadius = 24
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)

        // Hairline border
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor

        // Blur background clipped to corners
        cardBlurView.translatesAutoresizingMaskIntoConstraints = false
        cardBlurView.layer.cornerRadius = 24
        cardBlurView.layer.cornerCurve = .continuous
        cardBlurView.clipsToBounds = true
        cardView.addSubview(cardBlurView)

        NSLayoutConstraint.activate([
            cardBlurView.topAnchor.constraint(equalTo: cardView.topAnchor),
            cardBlurView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            cardBlurView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            cardBlurView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])

        // Optional handle for polish
        cardHandle.translatesAutoresizingMaskIntoConstraints = false
        cardHandle.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        cardHandle.layer.cornerRadius = 2.5
        cardBlurView.contentView.addSubview(cardHandle)

        NSLayoutConstraint.activate([
            cardHandle.topAnchor.constraint(equalTo: cardBlurView.contentView.topAnchor, constant: 10),
            cardHandle.centerXAnchor.constraint(equalTo: cardBlurView.contentView.centerXAnchor),
            cardHandle.widthAnchor.constraint(equalToConstant: 38),
            cardHandle.heightAnchor.constraint(equalToConstant: 5)
        ])

        // Content container
        cardContentView.translatesAutoresizingMaskIntoConstraints = false
        cardBlurView.contentView.addSubview(cardContentView)

        NSLayoutConstraint.activate([
            cardContentView.topAnchor.constraint(equalTo: cardBlurView.contentView.topAnchor),
            cardContentView.leadingAnchor.constraint(equalTo: cardBlurView.contentView.leadingAnchor),
            cardContentView.trailingAnchor.constraint(equalTo: cardBlurView.contentView.trailingAnchor),
            cardContentView.bottomAnchor.constraint(equalTo: cardBlurView.contentView.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        let cardTop = cardView.topAnchor.constraint(greaterThanOrEqualTo: view.centerYAnchor, constant: -24)
        cardTop.priority = .defaultHigh
        cardTop.isActive = true

        // Buttons row
        let buttonsRow = UIStackView(arrangedSubviews: [confirmButton, returnButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 10

        // ✅ Key fix: allow uneven widths so long title fits
        buttonsRow.distribution = .fillProportionally

        // Main stack (same structure/ordering as before)
        let stack = UIStackView(arrangedSubviews: [instructionLabel, statusLabel, detailLabel, buttonsRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardContentView.addSubview(stack)

        cardView.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.layoutMarginsGuide.topAnchor, constant: 10), // room for handle
            stack.leadingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: cardView.layoutMarginsGuide.bottomAnchor)
        ])

        // Labels (modern hierarchy)
        instructionLabel.text = "Tap anywhere on the map to drop a pin."
        instructionLabel.font = .preferredFont(forTextStyle: .footnote)
        instructionLabel.textColor = UIColor.white.withAlphaComponent(0.78)

        statusLabel.font = .preferredFont(forTextStyle: .title3)
        statusLabel.text = "Choose a destination to check availability."
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .left
        statusLabel.textColor = .white

        detailLabel.font = .preferredFont(forTextStyle: .callout)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        detailLabel.numberOfLines = 0

        // Helper to keep button titles on one line + shrink if needed
        func tuneButtonTitle(_ button: UIButton) {
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.lineBreakMode = .byClipping
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.75
        }

        // Buttons (same actions/behavior, updated look)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "Confirm Drop-Off"
            config.image = UIImage(systemName: "paperplane.fill")
            config.imagePadding = 6
            config.cornerStyle = .capsule

            // Modern insets so text/icon aren't cramped
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)

            config.baseBackgroundColor = UIColor.systemCyan.withAlphaComponent(0.95)
            config.baseForegroundColor = .black
            confirmButton.configuration = config
        } else {
            confirmButton.setTitle("Confirm Drop-Off", for: .normal)
            confirmButton.backgroundColor = .systemBlue
            confirmButton.setTitleColor(.white, for: .normal)
            confirmButton.layer.cornerRadius = 12
            confirmButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        }

        // Slightly more compact height (still tappable)
        confirmButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        confirmButton.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        tuneButtonTitle(confirmButton)
        confirmButton.addTarget(self, action: #selector(confirmDropoff), for: .touchUpInside)
        setConfirmButtonEnabled(false)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "Return"
            config.image = UIImage(systemName: "arrow.uturn.backward.circle.fill")
            config.imagePadding = 6
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.14)
            config.baseForegroundColor = .white
            returnButton.configuration = config
        } else {
            returnButton.setTitle("Return", for: .normal)
            returnButton.tintColor = .systemOrange
        }
        returnButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        returnButton.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        tuneButtonTitle(returnButton)
        returnButton.addTarget(self, action: #selector(returnToBase), for: .touchUpInside)
        setReturnButtonEnabled(false)

        // ✅ Encourage "Return" to stay smaller, and "Confirm" to take extra space
        returnButton.setContentHuggingPriority(.required, for: .horizontal)
        returnButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        confirmButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        confirmButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        setupZoomControls()

        // Make the map tappable
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        map.addGestureRecognizer(tap)

        centerMap(on: Constants.storeCoordinate)
        placeDroneAnnotation(at: Constants.storeCoordinate)
    }

    private func setConfirmButtonEnabled(_ enabled: Bool) {
        confirmButton.isEnabled = enabled
        confirmButton.alpha = enabled ? 1 : 0.5
    }

    private func setReturnButtonEnabled(_ enabled: Bool) {
        returnButton.isEnabled = enabled
        returnButton.alpha = enabled ? 1 : 0.4
    }

    private func updateStatus(primary: String, detail: String?) {
        statusLabel.text = primary
        detailLabel.text = detail
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 1_500) {
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: radius,
                                        longitudinalMeters: radius)
        map.setRegion(region, animated: false)
    }

    private func zoomMapToInclude(_ destination: CLLocationCoordinate2D) {
        var coordinates = [Constants.storeCoordinate, destination]
        let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        let paddedRect = map.mapRectThatFits(polyline.boundingMapRect,
                                             edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 260, right: 40))
        map.setVisibleMapRect(paddedRect, animated: true)
    }

    // MARK: Map – add store marker -----------------------------------------
    private func addStoreAnnotation() {
        let ann = MKPointAnnotation()
        ann.coordinate = Constants.storeCoordinate
        ann.title = "Store"
        map.addAnnotation(ann)
    }

    private func placeDroneAnnotation(at coordinate: CLLocationCoordinate2D) {
        if let droneAnnotation = droneAnnotation {
            droneAnnotation.coordinate = coordinate
        } else {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Drone"
            droneAnnotation = annotation
            map.addAnnotation(annotation)
        }
    }

    private func clearRouteVisuals() {
        map.removeOverlays(map.overlays)
    }

    private func mapItem(for coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26.0, *) {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return MKMapItem(location: location, address: nil)
        } else {
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }

    // MARK: Location permission (optional but recommended)
    private func requestLocationPermission() {
        let hasUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
        guard hasUsageDescription else {
            // Avoid triggering a runtime crash if the Info.plist entry is missing.
            map.showsUserLocation = false
            return
        }

        locationManager.requestWhenInUseAuthorization()
        map.showsUserLocation = true
    }

    // MARK: User taps the map – pick destination ---------------------------
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: map)
        let coordinate = map.convert(point, toCoordinateFrom: map)

        // Remove any previous destination annotation
        let oldDestinations = map.annotations.filter { ($0.title ?? "") == "Destination" }
        map.removeAnnotations(oldDestinations)

        let ann = MKPointAnnotation()
        ann.coordinate = coordinate
        ann.title = "Destination"
        map.addAnnotation(ann)

        destination = coordinate
        instructionLabel.text = "Looks good! Confirm to start the flight."
        updateStatus(primary: "Ready to deliver.", detail: "We'll simulate weather safety before take-off.")
        setConfirmButtonEnabled(true)
        setReturnButtonEnabled(false)
        zoomMapToInclude(coordinate)
        clearRouteVisuals()
    }

    // MARK: Confirm drop-off -----------------------------------------------
    @objc private func confirmDropoff() {
        guard let dest = destination else { return }
        updateStatus(primary: "Drone warming up…", detail: "Checking weather and plotting a route.")
        setConfirmButtonEnabled(false)
        drone.status = .flying
        flightStartCoordinate = drone.coordinate

        deliveryService.startFlight(from: drone.coordinate,
                                    to: dest,
                                    progressHandler: { [weak self] eta, feasible, progress in
            guard let self = self else { return }
            let etaText = self.etaFormatter.string(from: max(eta, 0)) ?? "--"
            let detail = feasible ? "Estimated arrival: \(etaText)" : "Weather risk detected. We'll pause for safety."
            let title = feasible ? "Drone is on the way 🚁" : "Flight paused"
            self.updateStatus(primary: title, detail: detail)
            self.updateLiveDronePosition(progress: progress, towards: dest)
            if !feasible {
                self.drone.status = .failed
                self.setConfirmButtonEnabled(true)
            }
        }, completion: { [weak self] delivered in
            guard let self = self, let destination = self.destination else { return }
            self.setConfirmButtonEnabled(true)

            if delivered {
                self.drone.status = .delivered
                self.updateStatus(primary: "Package delivered 🎉",
                                  detail: "Animating the final leg of the route.")
                self.animateDrone(to: destination)
                self.setReturnButtonEnabled(true)
            } else {
                self.updateStatus(primary: "Unable to fly right now.",
                                  detail: "Please try another spot or wait for better weather.")
            }
        })
    }

    // MARK: Drone animation along the computed route -----------------------
    private func animateDrone(to destination: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = mapItem(for: drone.coordinate)
        request.destination = mapItem(for: destination)

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            guard error == nil, let route = response?.routes.first else {
                self.updateStatus(primary: "Could not plot a route.",
                                  detail: "Check your connection and try again.")
                return
            }

            self.clearRouteVisuals()
            self.map.addOverlay(route.polyline)
            self.map.setVisibleMapRect(route.polyline.boundingMapRect,
                                       edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 260, right: 40),
                                       animated: true)

            var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                                       count: route.polyline.pointCount)
            route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: route.polyline.pointCount))

            var index = 0
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                guard index < coordinates.count else {
                    timer.invalidate()
                    self.updateStatus(primary: "All done!", detail: "Set a new destination whenever you're ready.")
                    return
                }

                let coordinate = coordinates[index]
                self.drone.coordinate = coordinate
                self.placeDroneAnnotation(at: coordinate)
                index += 1
            }
        }
    }

    // MARK: Live interpolation during simulated flight ----------------------
    private func updateLiveDronePosition(progress: Double, towards destination: CLLocationCoordinate2D) {
        guard let start = flightStartCoordinate else { return }
        let clamped = min(max(progress, 0), 1)
        let lat = start.latitude + (destination.latitude - start.latitude) * clamped
        let lon = start.longitude + (destination.longitude - start.longitude) * clamped
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        drone.coordinate = coord
        placeDroneAnnotation(at: coord)
    }

    // MARK: Zoom controls ----------------------------------------------------
    private func setupZoomControls() {
        zoomStack.axis = .vertical
        zoomStack.spacing = 8
        zoomStack.translatesAutoresizingMaskIntoConstraints = false
        let plus = makeZoomButton(symbol: "plus")
        plus.addTarget(self, action: #selector(zoomIn), for: .touchUpInside)
        let minus = makeZoomButton(symbol: "minus")
        minus.addTarget(self, action: #selector(zoomOut), for: .touchUpInside)
        zoomStack.addArrangedSubview(plus)
        zoomStack.addArrangedSubview(minus)

        view.addSubview(zoomStack)
        NSLayoutConstraint.activate([
            zoomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            zoomStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    private func makeZoomButton(symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.85)
        button.layer.cornerRadius = 14
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }

    @objc private func zoomIn() {
        var region = map.region
        region.span.latitudeDelta *= 0.6
        region.span.longitudeDelta *= 0.6
        map.setRegion(region, animated: true)
    }

    @objc private func zoomOut() {
        var region = map.region
        region.span.latitudeDelta /= 0.6
        region.span.longitudeDelta /= 0.6
        map.setRegion(region, animated: true)
    }

    // MARK: Return to base ---------------------------------------------------
    @objc private func returnToBase() {
        setReturnButtonEnabled(false)
        updateStatus(primary: "Returning to base…", detail: "Routing back to the store.")
        animateDrone(to: Constants.storeCoordinate)
        drone.status = .idle
    }
}
