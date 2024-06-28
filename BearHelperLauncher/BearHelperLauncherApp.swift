import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainAppIdentifier = "net.fodaveg.bearhelper" // Asegúrate de que este es el identificador correcto de la aplicación principal

        do {
            if SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
                print("Registered main app for launch at login")
            } else {
                print("Main app already registered for launch at login")
            }
        } catch {
            print("Failed to register main app for launch at login: \(error)")
        }

        NSApp.terminate(nil)
    }
}
