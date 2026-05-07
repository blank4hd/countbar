import Foundation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    private let service = SMAppService.mainApp

    private(set) var isEnabled: Bool

    private init() {
        self.isEnabled = service.status == .enabled
    }

    /// Toggle on/off. Returns true on success.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if service.status == .enabled {
                    isEnabled = true
                    return true
                }
                try service.register()
            } else {
                try service.unregister()
            }
            isEnabled = (service.status == .enabled)
            return true
        } catch {
            print("LaunchAtLogin: failed to set enabled=\(enabled): \(error)")
            // Re-sync state in case it changed despite the error
            isEnabled = (service.status == .enabled)
            return false
        }
    }

    /// Re-read state from the system (useful when returning from the background).
    func refresh() {
        isEnabled = service.status == .enabled
    }
}
