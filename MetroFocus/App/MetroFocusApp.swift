import SwiftUI
import SwiftData

@main
struct MetroFocusApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appDelegate
    var body: some Scene { WindowGroup { BootstrapView().preferredColorScheme(.dark) } }
}

struct BootstrapView: View {
    @State private var model: AppModel?
    @State private var loadError: String?
    var body: some View {
        Group {
            if let model { MetroRootView().environment(model) }
            else if loadError != nil {
                VStack(spacing: 22) {
                    MetroMark()
                    Text(L("暂时无法读取旅程", "Unable to load your journeys")).font(.title2.bold())
                    Text(L("已有记录会保留。请重试打开。", "Your saved journeys are safe. Please try again.")).foregroundStyle(MetroTheme.muted)
                    Button(L("重试", "Try again"), action: load).buttonStyle(MetroButtonStyle()).padding(.horizontal, 40)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(MetroTheme.background)
            } else { ProgressView().tint(MetroTheme.ink).frame(maxWidth: .infinity, maxHeight: .infinity).background(MetroTheme.background) }
        }.task { if model == nil { load() } }
    }
    @MainActor private func load() {
        do {
            var scale: Double = 1
            var storeURL: URL?
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--ui-testing") {
                let directory = URL.documentsDirectory.appendingPathComponent("UITestStore", isDirectory: true)
                if args.contains("--reset-store"), FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                storeURL = directory.appendingPathComponent("journeys.store")
                if let index = args.firstIndex(of: "--time-scale"), index + 1 < args.count { scale = Double(args[index + 1]) ?? 1 }
            }
            #endif
            let container = try MetroFocusStore.makeContainer(url: storeURL)
            model = AppModel(container: container, durationScale: scale)
            loadError = nil
        } catch { loadError = error.localizedDescription }
    }
}

struct MetroRootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var inbox = NotificationInbox.shared
    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            StationView().tabItem { Label(L("车站", "Station"), systemImage: "tram.fill") }.tag(0).accessibilityIdentifier("tabStation")
            AtlasView().tabItem { Label(L("路网", "Atlas"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(1).accessibilityIdentifier("tabAtlas")
            TicketLibraryView().tabItem { Label(L("票夹", "Tickets"), systemImage: "ticket") }.tag(2).accessibilityIdentifier("tabTickets")
        }
        .tint(MetroTheme.ink)
        .background(MetroTheme.background)
        .fullScreenCover(isPresented: $app.showsJourney) { JourneyView().environment(app) }
        .sheet(item: $app.presentedTicket) { ticket in NavigationStack { TicketDetailView(ticket: ticket).environment(app) } }
        .overlay(alignment: .top) {
            if let error = app.engine.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.subheadline)
                    Button(L("重试保存", "Retry saving")) { app.engine.retrySave() }.font(.headline)
                }.padding(16).background(MetroTheme.surface, in: RoundedRectangle(cornerRadius: 16)).padding()
            }
        }
        .onChange(of: app.engine.revision) { _, _ in app.synchronize() }
        .onChange(of: scenePhase) { _, phase in
            app.foreground = phase == .active
            if phase == .active { app.reconcileForeground() }
        }
        .onOpenURL { url in
            guard url.scheme == "metrofocus", url.host == "journey" else { return }
            guard let rawID = url.pathComponents.last, let id = UUID(uuidString: rawID) else { return }
            app.openJourney(id: id)
        }
        .onChange(of: inbox.pendingJourneyID) { _, id in
            if let id { app.openJourney(id: id); inbox.pendingJourneyID = nil }
        }
        .task {
            if let id = inbox.pendingJourneyID { app.openJourney(id: id); inbox.pendingJourneyID = nil }
            while !Task.isCancelled {
                app.tick()
                do { try await Task.sleep(for: .milliseconds(500)) } catch { break }
            }
        }
    }
}
