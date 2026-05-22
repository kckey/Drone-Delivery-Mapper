//
//  ViewController.swift
//  DroneDeliveryDemo
//

import UIKit
import MapKit

final class ViewController: UIViewController {

    private enum Theme {
        static let sand = UIColor(red: 0.95, green: 0.89, blue: 0.78, alpha: 1)
        static let parchment = UIColor(red: 0.99, green: 0.96, blue: 0.89, alpha: 1)
        static let panel = UIColor(red: 0.98, green: 0.93, blue: 0.83, alpha: 0.96)
        static let line = UIColor(red: 0.75, green: 0.63, blue: 0.44, alpha: 1)
        static let ink = UIColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1)
        static let muted = UIColor(red: 0.43, green: 0.35, blue: 0.25, alpha: 1)
        static let clay = UIColor(red: 0.68, green: 0.39, blue: 0.18, alpha: 1)
        static let clayDark = UIColor(red: 0.43, green: 0.23, blue: 0.11, alpha: 1)
        static let sage = UIColor(red: 0.39, green: 0.55, blue: 0.35, alpha: 1)
    }

    private let map = MKMapView()
    private let controlPanel = UIView()
    private let panelStack = UIStackView()
    private let instructionLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let etaValueLabel = UILabel()
    private let rangeValueLabel = UILabel()
    private let conditionValueLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let confirmButton = UIButton(type: .system)
    private let returnButton = UIButton(type: .system)
    private let zoomStack = UIStackView()

    private let locationManager = CLLocationManager()
    private var drone = Drone(start: Constants.storeCoordinate)
    private let deliveryService = DeliveryService()
    private let mapDelegate = MapViewDelegate()
    private var destination: CLLocationCoordinate2D?
    private var destinationAnnotation: MKPointAnnotation?
    private var droneAnnotation: MKPointAnnotation?
    private var routeOverlay: MKOverlay?
    private var flightStartCoordinate = Constants.storeCoordinate

    private lazy var etaFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        map.delegate = mapDelegate
        addStoreAnnotation()
        placeDroneAnnotation(at: Constants.storeCoordinate)
        centerMap(on: Constants.storeCoordinate)
        requestLocationPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controlPanel.layer.shadowPath = UIBezierPath(
            roundedRect: controlPanel.bounds,
            cornerRadius: 22
        ).cgPath
    }

    private func setupUI() {
        view.backgroundColor = Theme.sand
        setupMap()
        setupPanel()
        setupZoomControls()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        map.addGestureRecognizer(tap)
    }

    private func setupMap() {
        map.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(map)

        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            configuration.pointOfInterestFilter = .excludingAll
            map.preferredConfiguration = configuration
        } else {
            map.mapType = .mutedStandard
            map.pointOfInterestFilter = .excludingAll
        }

        map.overrideUserInterfaceStyle = .light
        map.showsCompass = false
        map.showsScale = true
        map.isRotateEnabled = false

        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupPanel() {
        controlPanel.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.backgroundColor = Theme.panel
        controlPanel.layer.cornerRadius = 22
        controlPanel.layer.cornerCurve = .continuous
        controlPanel.layer.borderWidth = 1
        controlPanel.layer.borderColor = Theme.line.withAlphaComponent(0.45).cgColor
        controlPanel.layer.shadowColor = UIColor.black.cgColor
        controlPanel.layer.shadowOpacity = 0.18
        controlPanel.layer.shadowRadius = 18
        controlPanel.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.addSubview(controlPanel)

        NSLayoutConstraint.activate([
            controlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            controlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            controlPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        panelStack.axis = .vertical
        panelStack.spacing = 12
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.addSubview(panelStack)

        NSLayoutConstraint.activate([
            panelStack.topAnchor.constraint(equalTo: controlPanel.topAnchor, constant: 18),
            panelStack.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 18),
            panelStack.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -18),
            panelStack.bottomAnchor.constraint(equalTo: controlPanel.bottomAnchor, constant: -18)
        ])

        let header = makeHeader()
        let metrics = makeMetricsGrid()
        let buttonRow = makeButtonRow()

        panelStack.addArrangedSubview(header)
        panelStack.addArrangedSubview(progressView)
        panelStack.addArrangedSubview(metrics)
        panelStack.addArrangedSubview(buttonRow)

        progressView.progress = 0
        progressView.trackTintColor = Theme.line.withAlphaComponent(0.22)
        progressView.progressTintColor = Theme.clay
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true

        setConfirmButtonEnabled(false)
        setReturnButtonEnabled(false)
        updateStatus(
            primary: "Select a delivery point",
            detail: "Tap the map to simulate a real-time drone delivery update.",
            eta: "--",
            range: "Awaiting route",
            condition: "Preflight idle"
        )
    }

    private func makeHeader() -> UIView {
        let container = UIView()

        instructionLabel.text = "Drone Delivery Operations"
        instructionLabel.font = .preferredFont(forTextStyle: .footnote)
        instructionLabel.textColor = Theme.muted

        statusLabel.font = .preferredFont(forTextStyle: .title2)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = Theme.ink
        statusLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .callout)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = Theme.muted
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [instructionLabel, statusLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func makeMetricsGrid() -> UIView {
        let row = UIStackView(arrangedSubviews: [
            makeMetric(title: "ETA", valueLabel: etaValueLabel),
            makeMetric(title: "Range", valueLabel: rangeValueLabel),
            makeMetric(title: "Condition", valueLabel: conditionValueLabel)
        ])
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func makeMetric(title: String, valueLabel: UILabel) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.parchment
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.line.withAlphaComponent(0.25).cgColor

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .caption2)
        titleLabel.textColor = Theme.muted

        valueLabel.font = .preferredFont(forTextStyle: .caption1)
        valueLabel.textColor = Theme.ink
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10)
        ])

        return card
    }

    private func makeButtonRow() -> UIView {
        stylePrimaryButton(confirmButton, title: "Start Delivery", symbol: "paperplane.fill")
        styleSecondaryButton(returnButton, title: "Return Base", symbol: "arrow.uturn.backward.circle.fill")

        confirmButton.addTarget(self, action: #selector(confirmDropoff), for: .touchUpInside)
        returnButton.addTarget(self, action: #selector(returnToBase), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [confirmButton, returnButton])
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func stylePrimaryButton(_ button: UIButton, title: String, symbol: String) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.image = UIImage(systemName: symbol)
            config.imagePadding = 7
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14)
            config.baseBackgroundColor = Theme.clay
            config.baseForegroundColor = .white
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.backgroundColor = Theme.clay
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 12
        }
    }

    private func styleSecondaryButton(_ button: UIButton, title: String, symbol: String) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = title
            config.image = UIImage(systemName: symbol)
            config.imagePadding = 7
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14)
            config.baseBackgroundColor = Theme.line.withAlphaComponent(0.18)
            config.baseForegroundColor = Theme.clayDark
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.tintColor = Theme.clayDark
        }
    }

    private func setConfirmButtonEnabled(_ enabled: Bool) {
        confirmButton.isEnabled = enabled
        confirmButton.alpha = enabled ? 1 : 0.45
    }

    private func setReturnButtonEnabled(_ enabled: Bool) {
        returnButton.isEnabled = enabled
        returnButton.alpha = enabled ? 1 : 0.45
    }

    private func updateStatus(primary: String, detail: String?, eta: String? = nil, range: String? = nil, condition: String? = nil) {
        statusLabel.text = primary
        detailLabel.text = detail
        if let eta {
            etaValueLabel.text = eta
        }
        if let range {
            rangeValueLabel.text = range
        }
        if let condition {
            conditionValueLabel.text = condition
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 1_500) {
        map.setRegion(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: radius, longitudinalMeters: radius),
            animated: false
        )
    }

    private func zoomMapToInclude(_ coordinate: CLLocationCoordinate2D) {
        let line = MKGeodesicPolyline(coordinates: [Constants.storeCoordinate, coordinate], count: 2)
        let padded = map.mapRectThatFits(
            line.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 80, left: 36, bottom: 285, right: 36)
        )
        map.setVisibleMapRect(padded, animated: true)
    }

    private func requestLocationPermission() {
        let hasUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
        guard hasUsageDescription else {
            map.showsUserLocation = false
            return
        }

        locationManager.requestWhenInUseAuthorization()
        map.showsUserLocation = true
    }

    private func addStoreAnnotation() {
        let annotation = MKPointAnnotation()
        annotation.coordinate = Constants.storeCoordinate
        annotation.title = "Dispatch Hub"
        map.addAnnotation(annotation)
    }

    private func placeDestinationAnnotation(at coordinate: CLLocationCoordinate2D) {
        if let destinationAnnotation {
            destinationAnnotation.coordinate = coordinate
        } else {
            let annotation = MKPointAnnotation()
            annotation.title = "Drop Zone"
            annotation.coordinate = coordinate
            destinationAnnotation = annotation
            map.addAnnotation(annotation)
        }
    }

    private func placeDroneAnnotation(at coordinate: CLLocationCoordinate2D) {
        if let droneAnnotation {
            droneAnnotation.coordinate = coordinate
        } else {
            let annotation = MKPointAnnotation()
            annotation.title = "Drone"
            annotation.coordinate = coordinate
            droneAnnotation = annotation
            map.addAnnotation(annotation)
        }
    }

    private func drawRoute(to coordinate: CLLocationCoordinate2D) {
        if let routeOverlay {
            map.removeOverlay(routeOverlay)
        }

        let route = MKGeodesicPolyline(coordinates: [drone.coordinate, coordinate], count: 2)
        routeOverlay = route
        map.addOverlay(route)
    }

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: map)
        let coordinate = map.convert(point, toCoordinateFrom: map)
        destination = coordinate
        placeDestinationAnnotation(at: coordinate)
        drawRoute(to: coordinate)
        zoomMapToInclude(coordinate)

        let distance = DeliveryService.distanceMeters(from: drone.coordinate, to: coordinate)
        let eta = distance / Constants.droneSpeedMetersPerSecond
        let etaText = etaFormatter.string(from: eta) ?? "--"
        updateStatus(
            primary: "Drop zone selected",
            detail: "Ready to stream live route updates to the customer view.",
            eta: etaText,
            range: Self.formatDistance(distance),
            condition: "Preflight ready"
        )
        progressView.progress = 0
        setConfirmButtonEnabled(true)
        setReturnButtonEnabled(false)
    }

    @objc private func confirmDropoff() {
        guard let destination else { return }

        setConfirmButtonEnabled(false)
        setReturnButtonEnabled(false)
        progressView.progress = 0
        flightStartCoordinate = drone.coordinate
        drone.status = .flying
        drawRoute(to: destination)

        updateStatus(
            primary: "Preflight check running",
            detail: "Checking simulated weather once, then streaming local route progress.",
            condition: "Checking"
        )

        deliveryService.startFlight(
            from: drone.coordinate,
            to: destination,
            progressHandler: { [weak self] eta, feasible, progress in
                guard let self else { return }
                let coordinate = self.interpolate(from: self.flightStartCoordinate, to: destination, progress: progress)
                self.drone.coordinate = coordinate
                self.placeDroneAnnotation(at: coordinate)
                self.progressView.setProgress(Float(progress), animated: true)

                let etaText = self.etaFormatter.string(from: max(eta, 0)) ?? "--"
                self.updateStatus(
                    primary: feasible ? "Delivery in progress" : "Delivery paused",
                    detail: feasible ? "Live position stream is updating from the route simulator." : "Weather safety policy blocked this route.",
                    eta: etaText,
                    condition: feasible ? "Clear" : "Weather hold"
                )
            },
            completion: { [weak self] delivered in
                guard let self else { return }
                self.setConfirmButtonEnabled(true)

                if delivered {
                    self.drone.status = .delivered
                    self.progressView.setProgress(1, animated: true)
                    self.updateStatus(
                        primary: "Package delivered",
                        detail: "The drone reached the selected drop zone. Return it to the dispatch hub when ready.",
                        eta: "00:00",
                        condition: "Delivered"
                    )
                    self.setReturnButtonEnabled(true)
                } else {
                    self.drone.status = .failed
                    self.updateStatus(
                        primary: "Route unavailable",
                        detail: "Try another drop zone or wait for safer operating conditions.",
                        condition: "Blocked"
                    )
                }
            }
        )
    }

    private func interpolate(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, progress: Double) -> CLLocationCoordinate2D {
        let clamped = min(max(progress, 0), 1)
        return CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * clamped,
            longitude: start.longitude + (end.longitude - start.longitude) * clamped
        )
    }

    private func setupZoomControls() {
        zoomStack.axis = .vertical
        zoomStack.spacing = 8
        zoomStack.translatesAutoresizingMaskIntoConstraints = false
        let plus = makeZoomButton(symbol: "plus")
        let minus = makeZoomButton(symbol: "minus")
        plus.addTarget(self, action: #selector(zoomIn), for: .touchUpInside)
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
        button.tintColor = Theme.ink
        button.backgroundColor = Theme.parchment.withAlphaComponent(0.94)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.line.withAlphaComponent(0.4).cgColor
        button.widthAnchor.constraint(equalToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
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

    @objc private func returnToBase() {
        let base = Constants.storeCoordinate
        destination = base
        setReturnButtonEnabled(false)
        setConfirmButtonEnabled(false)
        flightStartCoordinate = drone.coordinate
        drawRoute(to: base)

        updateStatus(
            primary: "Returning to dispatch hub",
            detail: "Streaming return route position updates.",
            condition: "Returning"
        )

        deliveryService.startFlight(
            from: drone.coordinate,
            to: base,
            progressHandler: { [weak self] eta, _, progress in
                guard let self else { return }
                let coordinate = self.interpolate(from: self.flightStartCoordinate, to: base, progress: progress)
                self.drone.coordinate = coordinate
                self.placeDroneAnnotation(at: coordinate)
                self.progressView.setProgress(Float(progress), animated: true)
                let etaText = self.etaFormatter.string(from: max(eta, 0)) ?? "--"
                self.updateStatus(
                    primary: "Returning to dispatch hub",
                    detail: "Drone is clearing the delivery zone.",
                    eta: etaText,
                    range: Self.formatDistance(DeliveryService.distanceMeters(from: coordinate, to: base)),
                    condition: "Returning"
                )
            },
            completion: { [weak self] _ in
                guard let self else { return }
                self.drone.status = .idle
                self.progressView.progress = 0
                self.updateStatus(
                    primary: "Drone ready",
                    detail: "Tap a new drop zone to begin another live delivery update.",
                    eta: "--",
                    range: "At hub",
                    condition: "Ready"
                )
                self.setConfirmButtonEnabled(self.destination != nil)
            }
        )
    }

    private static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1_000 {
            return String(format: "%.1f km", meters / 1_000)
        }
        return String(format: "%.0f m", meters)
    }
}
