import Foundation
import CoreLocation

/// One-shot async wrapper around CLLocationManager.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Failure: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: "Location access is off — enable it for Cloudy in System Settings › Privacy."
            case .unavailable: "Couldn't determine your location."
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentPlace() async throws -> Place {
        let location = try await locate()
        var place = Place(name: "My Location", latitude: location.coordinate.latitude,
                          longitude: location.coordinate.longitude, isCurrentLocation: true)
        if let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            place.name = mark.locality ?? mark.name ?? place.name
            place.region = mark.administrativeArea
            place.country = mark.country
        }
        return place
    }

    private func locate() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .denied, .restricted: throw Failure.denied
        default: break
        }
        return try await withCheckedThrowingContinuation { cont in
            continuation?.resume(throwing: Failure.unavailable)
            continuation = cont
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard continuation != nil else { return }
            switch manager.authorizationStatus {
            case .denied, .restricted: finish(.failure(Failure.denied))
            case .notDetermined: break
            default: manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let loc = locations.last { finish(.success(loc)) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(.failure(Failure.unavailable)) }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
