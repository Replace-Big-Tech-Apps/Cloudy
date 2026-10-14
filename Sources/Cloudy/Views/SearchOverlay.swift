import SwiftUI

/// City search as a V3ERA card over the desk.
struct SearchOverlay: View {
    @EnvironmentObject private var store: WeatherStore
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var highlighted = 0
    @State private var isLoading = false
    @FocusState private var focused: Bool

    /// Row 0 is always "current location".
    private var rowCount: Int { results.count + 1 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Search · Open-Meteo").eyebrow(size: 7.5)
                        TextField("", text: $query, prompt: Text("City name").foregroundStyle(V3.whisper))
                            .textFieldStyle(.plain)
                            .font(V3Font.condensed(26))
                            .foregroundStyle(V3.ink)
                            .focused($focused)
                            .onSubmit { pick(highlighted) }
                            .onKeyPress(.downArrow) { highlighted = min(rowCount - 1, highlighted + 1); return .handled }
                            .onKeyPress(.upArrow) { highlighted = max(0, highlighted - 1); return .handled }
                            .onExitCommand { close() }
                    }
                    if isLoading || store.isLocating {
                        ProgressView().controlSize(.small)
                    }
                    Text("Esc").eyebrow(V3.mute, size: 7)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .overlay(Rectangle().strokeBorder(V3.lineStrong))
                }
                .padding(.horizontal, 17)
                .frame(height: 72)
                .hairline(.bottom, color: V3.lineStrong)

                ResultRow(icon: "location.fill", title: "Use my location", subtitle: "Weather where you are",
                          trailing: nil, isHighlighted: highlighted == 0) { pick(0) }
                ForEach(Array(results.enumerated()), id: \.element.id) { i, place in
                    ResultRow(icon: "mappin", title: place.name, subtitle: place.subtitle,
                              trailing: place.coordinateLabel, isHighlighted: highlighted == i + 1) { pick(i + 1) }
                }
                if !query.trimmingCharacters(in: .whitespaces).isEmpty && results.isEmpty && !isLoading {
                    Text("No places match “\(query)”.")
                        .eyebrow(V3.mute, size: 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 17)
                        .frame(height: 52)
                }
            }
            .frame(width: 560)
            .paperCard()
            .padding(.top, 110)
        }
        .onAppear { focused = true }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            isLoading = true
            defer { isLoading = false }
            if let found = try? await OpenMeteo.search(q), !Task.isCancelled {
                withAnimation(V3.Motion.base) {
                    results = found
                    highlighted = found.isEmpty ? 0 : 1
                }
            }
        }
    }

    private func pick(_ index: Int) {
        if index == 0 {
            Task { await store.useCurrentLocation() }
        } else if results.indices.contains(index - 1) {
            store.add(results[index - 1])
        }
    }

    private func close() { store.isSearching = false }
}

private struct ResultRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: String?
    let isHighlighted: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(V3.ink)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(V3Font.condensed(19)).foregroundStyle(V3.ink).lineLimit(1)
                    if !subtitle.isEmpty { Text(subtitle).eyebrow(V3.mute, size: 7) }
                }
                Spacer()
                if let trailing { Text(trailing).eyebrow(V3.whisper, size: 7) }
                if isHighlighted {
                    Image(systemName: "return").font(.system(size: 10, weight: .bold)).foregroundStyle(V3.ink)
                }
            }
            .padding(.horizontal, 17)
            .frame(height: 52)
            .background(isHighlighted ? V3.signalWash : (hover ? V3.paperSoft : V3.paper))
            .overlay(alignment: .leading) { if isHighlighted { V3.signal.frame(width: 4) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hairline(.bottom)
        .onHover { hover = $0 }
    }
}
