# Drone Delivery Mapper

iOS MapKit proof-of-concept for real-time drone delivery updates.

The app lets a user select a drop zone on the map, runs a simulated preflight weather check, and streams live drone position and ETA updates from the dispatch hub to the selected destination. The UI uses a tan operations-dashboard theme intended for a delivery tracking demo.

## Features

- Tap-to-select delivery destination
- Dispatch hub, drop zone, and drone annotations
- Route overlay between drone and destination
- Real-time position interpolation
- ETA, range, condition, and progress status
- Return-to-base flow
- Weather feasibility check with a mock fallback when no OpenWeather key is configured
- Tan/light logistics dashboard styling

## Performance Notes

The simulator now checks weather once before takeoff and then performs local progress updates on a lightweight timer. This avoids repeated network work during the flight animation and makes the live update flow smoother.

## Configuration

Set `Constants.openWeatherKey` in `DroneDelivery/Constants.swift` to use real OpenWeather data. If left as `YOUR_OPENWEATHERMAP_KEY`, the app uses safe mock weather so the demo still works.

## Files

```text
DroneDelivery/
  ViewController.swift     Main MapKit delivery UI
  DeliveryService.swift    Flight simulation and ETA updates
  WeatherService.swift     Weather fetch and mock fallback
  MapViewDelegate.swift    Route and annotation styling
  Constants.swift          Demo configuration
```

## Build

Open the project in Xcode and run on an iOS simulator or device. This repository currently contains the app source files; if Xcode project metadata is missing locally, create a new iOS UIKit app target and add the files under `DroneDelivery/`.
