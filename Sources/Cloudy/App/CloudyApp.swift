import SwiftUI
import AppKit

@main
struct CloudyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = WeatherStore()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup("Cloudy") {
            ContentView()
                .environmentObject(store)
                .onAppear { Appearance.apply(appearance) }
                .onChange(of: appearance) { _, new in Appearance.apply(new) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 840)
        .commands { CloudyCommands(store: store) }

        Settings {
            SettingsView().environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Gallery.runIfRequested()
        NSWindow.allowsAutomaticWindowTabbing = false
        Appearance.apply(UserDefaults.standard.string(forKey: "appearance") ?? "system")
        // Lets `swift run` behave like a real app (dock icon, focus).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct CloudyCommands: Commands {
    @ObservedObject var store: WeatherStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Search Cities…") { store.isSearching = true }
                .keyboardShortcut("k")
            Button("Use My Location") { Task { await store.useCurrentLocation() } }
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
        CommandMenu("Weather") {
            Button("Refresh") { store.refreshSelected() }
                .keyboardShortcut("r")
            Divider()
            Button("Previous City") { store.cycle(-1) }
                .keyboardShortcut("[")
            Button("Next City") { store.cycle(1) }
                .keyboardShortcut("]")
            Divider()
            Picker("Units", selection: $store.unit) {
                Text("Celsius").tag(TempUnit.celsius)
                Text("Fahrenheit").tag(TempUnit.fahrenheit)
            }
        }
        CommandMenu("Atmosphere") {
            Button("Live Weather") { store.setPreview(nil); store.previewTime = .auto }
                .keyboardShortcut("0")
            Divider()
            ForEach(Array(WeatherKind.allCases.enumerated()), id: \.element) { index, kind in
                if index < 9 {
                    Button(kind.title) { store.setPreview(kind) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                } else {
                    Button(kind.title) { store.setPreview(kind) }
                }
            }
            Divider()
            Button("Toggle Day / Night") { store.toggleNight() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: WeatherStore
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Picker("Units", selection: $store.unit) {
                Text("Celsius").tag(TempUnit.celsius)
                Text("Fahrenheit").tag(TempUnit.fahrenheit)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
    }
}
