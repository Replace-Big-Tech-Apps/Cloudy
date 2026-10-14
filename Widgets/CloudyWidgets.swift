import SwiftUI
import WidgetKit

@main
struct CloudyWidgets: WidgetBundle {
    var body: some Widget {
        NowWidget()
        CitiesWidget()
    }
}

struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.cloudy.now", provider: CloudyProvider()) { entry in
            NowWidgetView(entry: entry)
        }
        .configurationDisplayName("Cloudy")
        .description("The sky over the city selected in Cloudy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CitiesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.cloudy.cities", provider: CloudyProvider(allCities: true)) { entry in
            CitiesWidgetView(entry: entry)
        }
        .configurationDisplayName("Cloudy Cities")
        .description("All your saved cities at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
