import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class WeatherStore: ObservableObject {
    enum PreviewTime: String, CaseIterable { case auto, day, night }

    @Published var places: [Place] { didSet { persist(); syncWidgets() } }
    @Published var selectedID: Place.ID? { didSet { defaults.set(selectedID, forKey: Keys.selected); syncWidgets() } }
    @Published private(set) var forecasts: [Place.ID: Forecast] = [:]
    @Published private(set) var loadingIDs: Set<Place.ID> = []
    @Published private(set) var isLocating = false
    @Published var errorMessage: String?

    /// Atmosphere preview: overrides the live sky so every animation can be explored.
    @Published var preview: WeatherKind?
    @Published var previewTime: PreviewTime = .auto
    @Published var unit: TempUnit { didSet { defaults.set(unit.rawValue, forKey: Keys.unit); syncWidgets() } }
    @Published var isSearching = false

    private let defaults = UserDefaults.standard
    private let location = LocationProvider()
    private var refreshLoop: Task<Void, Never>?
    private var widgetSync: Task<Void, Never>?

    private enum Keys {
        static let places = "cloudy.places"
        static let selected = "cloudy.selected"
        static let unit = "cloudy.unit"
        static let launched = "cloudy.launched"
    }

    static let starterPlaces: [Place] = [
        Place(name: "Innsbruck", region: "Tyrol", country: "Austria", latitude: 47.2692, longitude: 11.4041),
        Place(name: "Vienna", region: "Vienna", country: "Austria", latitude: 48.2085, longitude: 16.3721),
        Place(name: "London", region: "England", country: "United Kingdom", latitude: 51.5085, longitude: -0.1257),
        Place(name: "Tokyo", region: "Tokyo", country: "Japan", latitude: 35.6895, longitude: 139.6917),
        Place(name: "Reykjavík", region: "Capital Region", country: "Iceland", latitude: 64.1355, longitude: -21.8954),
    ]

    init() {
        if let data = defaults.data(forKey: Keys.places),
           let saved = try? JSONDecoder().decode([Place].self, from: data), !saved.isEmpty {
            places = saved
        } else {
            places = Self.starterPlaces
        }
        unit = TempUnit(rawValue: defaults.string(forKey: Keys.unit) ?? "") ?? .celsius
        selectedID = defaults.string(forKey: Keys.selected)
        if selectedID == nil || !places.contains(where: { $0.id == selectedID }) {
            selectedID = places.first?.id
        }

        syncWidgets()

        // `--preview <kind> [--night|--day]` opens straight into a preview sky.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--preview"), args.indices.contains(i + 1) {
            preview = WeatherKind(rawValue: args[i + 1])
        }
        if args.contains("--night") { previewTime = .night }
        if args.contains("--day") { previewTime = .day }

        refreshLoop = Task { [weak self] in
            await self?.refreshAll()
            if let self, !self.defaults.bool(forKey: Keys.launched) {
                self.defaults.set(true, forKey: Keys.launched)
                await self.useCurrentLocation(silently: true)
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(600))
                await self?.refreshAll()
            }
        }
    }

    // MARK: Derived

    var selected: Place? { places.first { $0.id == selectedID } }
    var forecast: Forecast? { selectedID.flatMap { forecasts[$0] } }
    var isLoadingSelected: Bool { selectedID.map(loadingIDs.contains) ?? false }

    var sceneKind: WeatherKind { preview ?? forecast?.kind ?? .partlyCloudy }

    var sceneIsDay: Bool {
        switch previewTime {
        case .day: return true
        case .night: return false
        case .auto:
            if let forecast { return forecast.current.isDay }
            let hour = Calendar.current.component(.hour, from: .now)
            return (7..<19).contains(hour)
        }
    }

    var sceneConfig: SceneConfig {
        SceneConfig.make(kind: sceneKind, isDay: sceneIsDay,
                         windKmh: preview == nil ? forecast?.current.windSpeed : nil)
    }

    // MARK: Actions

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for place in places {
                group.addTask { await self.refresh(place) }
            }
        }
    }

    func refreshSelected() {
        guard let selected else { return }
        Task { await refresh(selected) }
    }

    func refresh(_ place: Place) async {
        loadingIDs.insert(place.id)
        defer { loadingIDs.remove(place.id) }
        do {
            let f = try await OpenMeteo.forecast(for: place)
            withAnimation(V3.Motion.slow) { forecasts[place.id] = f }
        } catch is CancellationError {
        } catch {
            if place.id == selectedID {
                errorMessage = "Couldn't reach Open-Meteo for \(place.name)."
            }
        }
    }

    func select(_ place: Place) {
        withAnimation(V3.Motion.slow) { selectedID = place.id }
        if forecasts[place.id] == nil || Date.now.timeIntervalSince(forecasts[place.id]!.fetchedAt) > 600 {
            Task { await refresh(place) }
        }
    }

    func add(_ place: Place) {
        if !places.contains(where: { $0.id == place.id }) {
            if place.isCurrentLocation {
                places.removeAll { $0.isCurrentLocation }
                places.insert(place, at: 0)
            } else {
                places.append(place)
            }
        }
        isSearching = false
        select(place)
    }

    func remove(_ place: Place) {
        guard places.count > 1 else { return }
        let index = places.firstIndex { $0.id == place.id } ?? 0
        places.removeAll { $0.id == place.id }
        forecasts[place.id] = nil
        if selectedID == place.id {
            select(places[min(index, places.count - 1)])
        }
    }

    func cycle(_ step: Int) {
        guard let i = places.firstIndex(where: { $0.id == selectedID }), !places.isEmpty else { return }
        select(places[(i + step + places.count) % places.count])
    }

    func useCurrentLocation(silently: Bool = false) async {
        isLocating = true
        defer { isLocating = false }
        do {
            let place = try await location.currentPlace()
            places.removeAll { $0.isCurrentLocation }
            places.insert(place, at: 0)
            isSearching = false
            select(place)
            await refresh(place)
        } catch {
            if !silently { errorMessage = error.localizedDescription }
        }
    }

    func setPreview(_ kind: WeatherKind?) {
        withAnimation(V3.Motion.slow) { preview = kind }
    }

    func toggleNight() {
        withAnimation(V3.Motion.slow) {
            previewTime = sceneIsDay ? .night : .day
        }
    }

    /// Opens the city a widget was tapped on.
    func open(_ url: URL) {
        guard let id = SharedStore.placeID(from: url), let place = places.first(where: { $0.id == id }) else { return }
        isSearching = false
        select(place)
    }

    /// Shares cities + units with the widgets and asks WidgetKit to redraw (debounced).
    private func syncWidgets() {
        widgetSync?.cancel()
        widgetSync = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            SharedStore.save(.init(places: self.places, selectedID: self.selectedID, unit: self.unit))
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(places) {
            defaults.set(data, forKey: Keys.places)
        }
    }
}
