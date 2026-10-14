import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WeatherStore

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopBar()
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        HeroView()
                        DetailGrid()
                    }
                    .frame(maxWidth: .infinity)
                    DailyPanel()
                        .frame(width: 320)
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(V3.desk)
            }

            if store.isSearching {
                SearchOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
            if let message = store.errorMessage {
                ToastView(message: message) { store.errorMessage = nil }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .background(WindowChrome())
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1080, minHeight: 760)
        .onOpenURL { store.open($0) }
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .animation(V3.Motion.base, value: store.isSearching)
        .animation(V3.Motion.slow, value: store.errorMessage)
    }
}

/// Paper slip with a yellow edge, like a V3ERA notice.
struct ToastView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("Notice").eyebrow(V3.mute, size: 7.5)
            Text(message)
                .font(V3Font.mono(11, .medium))
                .foregroundStyle(V3.ink)
            SquareButton(symbol: "xmark", help: "Dismiss", size: 24, action: dismiss)
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: 46)
        .overlay(alignment: .leading) { V3.signal.frame(width: 4) }
        .paperCard()
        .task {
            try? await Task.sleep(for: .seconds(6))
            dismiss()
        }
    }
}
