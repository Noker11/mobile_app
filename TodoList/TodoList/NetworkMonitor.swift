import Foundation
import Network

@MainActor
final class NetworkMonitor {
    private(set) var isConnected = true
    var onChange: ((Bool) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                guard let self, connected != self.isConnected else { return }
                self.isConnected = connected
                self.onChange?(connected)
            }
        }
        monitor.start(queue: queue)
    }
}
