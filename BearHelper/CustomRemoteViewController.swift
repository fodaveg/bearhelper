import Cocoa

class CustomRemoteViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Configurar la vista y agregar cualquier inicialización necesaria aquí
    }
    
    func handleServiceTermination(with error: Error) {
        // Manejar el error aquí, puedes agregar alertas o logs adicionales
        print("Remote view service terminated with error: \(error.localizedDescription)")
    }
}
