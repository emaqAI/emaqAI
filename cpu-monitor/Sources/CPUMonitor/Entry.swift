import SwiftUI

@main
enum Entry {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--log-sample") {
            StatsLogger.run()
        } else {
            CPUMonitorApp.main()
        }
    }
}
