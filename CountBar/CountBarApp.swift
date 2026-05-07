import SwiftUI
import SwiftData
import AppKit

@main
struct CountBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Required for @main to compile, but we don't actually use any windows.
        // Settings is invisible by default for menu-bar-only apps.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appearanceObservation: NSKeyValueObservation?

    private(set) var modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Counter.self, CounterDailyEntry.self)
        } catch {
            // Wipe-and-retry on schema mismatch during development.
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            return try! ModelContainer(for: Counter.self, CounterDailyEntry.self)
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupStatusItem()
        setupPopover()
        refreshIcon()

        // Re-render the icon when appearance changes (light/dark) or counters change.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.refreshIcon() }
        }
        
        NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshIcon() }
        }
        
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshIcon() }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            togglePopover(sender)
        } else {
            incrementActiveCounter()
            bounce(sender)
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient   // closes when user clicks outside
        popover.animates = true

        let rootView = CounterListView()
            .modelContainer(modelContainer)

        let hosting = NSHostingController(rootView: rootView)
        // Let SwiftUI determine size, but cap height
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            // Bring the popover's window forward so keyboard input works
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    // MARK: - Dashboard window

    private var dashboardWindow: NSWindow?

    func showDashboard() {
        print("🟢 showDashboard called")
        NSApp.setActivationPolicy(.regular)
        print("🟢 Activation policy set to .regular")

        if let window = dashboardWindow {
            print("🟢 Reusing existing window")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        print("🟢 Creating new window")
        let rootView = DashboardView()
            .modelContainer(modelContainer)

        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "CountBar Dashboard"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = dashboardWindowDelegate

        dashboardWindow = window
        print("🟢 Window created, frame: \(window.frame), level: \(window.level.rawValue)")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("🟢 Window made key and front, isVisible: \(window.isVisible)")
    }

    private lazy var dashboardWindowDelegate: DashboardWindowDelegate = {
        DashboardWindowDelegate { [weak self] in
            self?.dashboardWindow = nil
        // Return to accessory mode so we hide from the dock again.
            NSApp.setActivationPolicy(.accessory)
        }
    }()

    // MARK: - Counter actions

    private func incrementActiveCounter() {
        let context = modelContainer.mainContext
        let store = CounterStore(context: context)
        let activeID = UserDefaults.standard.string(forKey: "activeCounterID") ?? ""

        let descriptor = FetchDescriptor<Counter>()
        guard let counters = try? context.fetch(descriptor), !counters.isEmpty else { return }

        let active = counters.first { $0.id.uuidString == activeID } ?? counters.first
        if let active {
            store.increment(active)
            try? context.save()
        }

        refreshIcon()
    }

    // MARK: - Icon rendering

    private func refreshIcon() {
        guard let button = statusItem.button else { return }

        let progress = currentProgress()
        let image = MenuBarIconRenderer.render(
            progress: progress,
            pointSize: 22,
            appearance: NSApp.effectiveAppearance
        )
        button.image = image
    }

    private func currentProgress() -> Double {
        let context = modelContainer.mainContext
        let store = CounterStore(context: context)
        let activeID = UserDefaults.standard.string(forKey: "activeCounterID") ?? ""

        let descriptor = FetchDescriptor<Counter>()
        guard let counters = try? context.fetch(descriptor) else { return 0 }
        let active = counters.first { $0.id.uuidString == activeID } ?? counters.first

        guard let active, active.goal > 0 else { return 0 }
        let value = store.displayValue(for: active)
        return min(max(Double(value) / Double(active.goal), 0), 1)
    }

    // MARK: - Animation

    private func bounce(_ button: NSStatusBarButton) {
        guard let layer = button.layer else { return }

        // Set anchor to center for proper scaling
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let bounds = layer.bounds
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.25
        scale.duration = 0.08
        scale.autoreverses = true
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(scale, forKey: "bounce")
    }
    

}

final class DashboardWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
