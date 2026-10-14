import SwiftUI

struct TopBar: View {
    @EnvironmentObject private var store: WeatherStore
    @AppStorage("appearance") private var appearance = "system"
    @State private var showAtmosphere = false

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 84)
            HStack(spacing: 8) {
                Wordmark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cloudy").font(V3Font.condensed(17, .medium)).foregroundStyle(V3.ink)
                    Text("Weather desk").eyebrow(size: 6.5)
                }
            }
            .frame(width: 140, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(store.places.enumerated()), id: \.element.id) { i, place in
                        CitySegment(index: i, place: place,
                                    temp: store.forecasts[place.id].map { store.unit.temp($0.current.temperature) },
                                    selected: place.id == store.selectedID)
                    }
                    AddSegment { store.isSearching = true }
                }
                .frame(height: WindowChrome.barHeight)
                .hairline(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .hairline(.trailing)

            HStack(spacing: 6) {
                if store.preview != nil {
                    SignalTag(text: "Preview")
                        .padding(.trailing, 4)
                        .transition(.opacity)
                }
                HStack(spacing: 0) {
                    ForEach(TempUnit.allCases, id: \.self) { u in
                        Chip(title: u.symbol, on: store.unit == u, width: 34, height: 28) {
                            withAnimation(V3.Motion.slow) { store.unit = u }
                        }
                    }
                }
                SquareButton(symbol: "sparkles", help: "Atmosphere: preview every sky", size: 28, filled: showAtmosphere) {
                    showAtmosphere.toggle()
                }
                .popover(isPresented: $showAtmosphere, arrowEdge: .bottom) {
                    AtmospherePicker().environmentObject(store)
                }
                SquareButton(symbol: "arrow.clockwise", help: "Refresh (⌘R)", size: 28, spinning: store.isLoadingSelected) {
                    store.refreshSelected()
                }
                SquareButton(symbol: Appearance.symbol(appearance), help: "Appearance: \(appearance.capitalized)", size: 28) {
                    appearance = Appearance.next(appearance)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 18)
        }
        .frame(height: WindowChrome.barHeight)
        .background(V3.paper)
        .hairline(.bottom, color: V3.lineStrong)
        .animation(V3.Motion.base, value: store.preview)
    }
}

/// Numbered city segment ("01 · 12°" over "VIENNA"); the selected one is ink with a yellow index.
private struct CitySegment: View {
    @EnvironmentObject private var store: WeatherStore
    let index: Int
    let place: Place
    let temp: Int?
    let selected: Bool
    @State private var hover = false

    var body: some View {
        Button { store.select(place) } label: {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Text(String(format: "%02d", index + 1)).eyebrow(selected ? V3.signal : V3.whisper, size: 7)
                    if let temp {
                        Text("\(temp)°").eyebrow(selected ? V3.inverse.opacity(0.6) : V3.whisper, size: 7)
                            .contentTransition(.numericText(value: Double(temp)))
                    }
                }
                HStack(spacing: 4) {
                    if place.isCurrentLocation {
                        Image(systemName: "location.fill").font(.system(size: 7, weight: .bold))
                    }
                    Text(place.name).lineLimit(1)
                }
                .eyebrow(selected ? V3.inverse : V3.mute, size: 8)
            }
            .padding(.horizontal, 16)
            .frame(minWidth: 104, maxHeight: .infinity)
            .background(selected ? V3.ink : (hover ? V3.paperSoft : V3.paper))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hairline(.trailing)
        .onHover { hover = $0 }
        .help(index < 9 ? "\(place.name) (⌘\(index + 1))" : place.name)
        .contextMenu {
            Button("Refresh") { Task { await store.refresh(place) } }
            Button("Remove \(place.name)", role: .destructive) { store.remove(place) }
                .disabled(store.places.count < 2)
        }
    }
}

private struct AddSegment: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(hover ? .black : V3.ink)
                Text("Add").eyebrow(hover ? .black : V3.mute, size: 7)
            }
            .frame(width: 64)
            .frame(maxHeight: .infinity)
            .background(hover ? V3.signal : V3.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hairline(.trailing)
        .onHover { hover = $0 }
        .help("Add a city (⌘K)")
    }
}

/// Lets you summon any sky on demand.
struct AtmospherePicker: View {
    @EnvironmentObject private var store: WeatherStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Atmosphere").eyebrow(size: 7.5)
                Text("Preview every sky").font(V3Font.condensed(20)).foregroundStyle(V3.ink)
            }
            .padding(.horizontal, 17)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .hairline(.bottom)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(WeatherKind.allCases) { kind in
                    SkyTile(kind: kind, isDay: store.sceneIsDay, on: store.preview == kind) { store.setPreview(kind) }
                }
            }

            HStack(spacing: 0) {
                ForEach([WeatherStore.PreviewTime.auto, .day, .night], id: \.self) { t in
                    Chip(title: t.rawValue.uppercased(), on: store.previewTime == t, width: 54) {
                        withAnimation(V3.Motion.slow) { store.previewTime = t }
                    }
                }
                Spacer()
            }
            .padding(14)
            .hairline(.top)

            BarButton(title: "Back to live weather · ⌘0", kind: .ink) {
                store.setPreview(nil)
                store.previewTime = .auto
            }
        }
        .frame(width: 400)
        .background(V3.paper)
    }
}

private struct SkyTile: View {
    let kind: WeatherKind
    let isDay: Bool
    let on: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                WeatherGlyph(kind: kind, isDay: isDay, size: 17, ink: on ? V3.inverse : (hover ? .black : V3.ink))
                    .frame(height: 22)
                Text(kind.title).eyebrow(on ? V3.inverse : (hover ? .black : V3.mute), size: 7).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(on ? V3.ink : (hover ? V3.signal : V3.paper))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hairline([.bottom, .trailing])
        .onHover { hover = $0 }
    }
}

/// Small app mark: the dot-matrix cloud from the icon, with the yellow sun.
struct Wordmark: View {
    var body: some View {
        Canvas { ctx, size in
            let n = 11, step = size.width / CGFloat(n)
            // The icon's cloud in unit coordinates: three puffs on a rounded base.
            let puffs: [(x: Double, y: Double, r: Double)] = [(0.27, 0.62, 0.15), (0.49, 0.50, 0.22), (0.73, 0.59, 0.18)]
            for row in 0..<n {
                for col in 0..<n {
                    let x = (Double(col) + 0.5) / Double(n), y = (Double(row) + 0.5) / Double(n)
                    let inPuff = puffs.contains { ($0.x - x) * ($0.x - x) + ($0.y - y) * ($0.y - y) < $0.r * $0.r }
                    let inBase = x > 0.14 && x < 0.86 && y > 0.6 && y < 0.8
                    guard inPuff || inBase else { continue }
                    let shade = min(1, max(0, (y - 0.3) / 0.5))
                    let s = step * (0.35 + 0.4 * shade)
                    ctx.fill(Path(CGRect(x: CGFloat(col) * step + (step - s) / 2, y: CGFloat(row) * step + (step - s) / 2, width: s, height: s)),
                             with: .color(V3.ink.opacity(0.45 + 0.5 * shade)))
                }
            }
            ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.74, y: size.height * 0.08, width: 6, height: 6)), with: .color(V3.signal))
        }
        .frame(width: 26, height: 26)
    }
}
