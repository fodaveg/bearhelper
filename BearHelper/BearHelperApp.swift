import Cocoa
import SwiftUI
import ServiceManagement

@main
struct BearHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(setLaunchAtLogin: appDelegate.setLaunchAtLogin)
        }
    }
}

extension String {
    func addingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return self.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
