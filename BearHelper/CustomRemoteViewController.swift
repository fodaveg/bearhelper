import Cocoa

class CustomRemoteViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func handleServiceTermination(with error: Error) {
        print("Remote view service terminated with error: \(error.localizedDescription)")
    }
}
