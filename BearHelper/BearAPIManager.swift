import AppKit

class BearAPIManager {
    static let shared = BearAPIManager()
    
    var searchCompletion: ((Result<[String], Error>) -> Void)?
    
    var createCompletion: ((Result<String, Error>) -> Void)?
    
    func handleCallback(url: URL) {
        if let host = url.host {
            switch host {
            case "open-daily-note-success":
                handleOpenDailyNoteSuccess(url: url)
            case "open-daily-note-error":
                handleOpenDailyNoteError(url: url)
            case "create-note-success":
                handleCreateNoteSuccess(url: url)
            case "create-note-error":
                handleCreateNoteError(url: url)
            case "searchSuccess":
                handleSearchSuccess(url: url)
            case "searchError":
                handleSearchError(url: url)
            case "openNoteSuccess":
                handleOpenNoteSuccess(url: url)
            case "openNoteError":
                handleOpenNoteError(url: url)
            case "createNoteSuccess":
                handleCreateNoteSuccess(url: url)
            case "createNoteError":
                handleCreateNoteError(url: url)
            default:
                break
            }
        }
    }
    
    
    func search(term: String, tag: String, completion: @escaping (Result<[String], Error>) -> Void) {
        
        self.searchCompletion = completion
        let successCallback = "fodabear://searchSuccess"
        let errorCallback = "fodabear://searchError"
        
        let searchURLString = "bear://x-callback-url/search?term=\(term)&tag=\(tag)&x-success=\(successCallback)&x-error=\(errorCallback)&show_window=no&token=D63CE7-0B1D55-C064A4"
        
        print("search note url: \(searchURLString)")
        
        openURL(searchURLString)
    }
    
    
    func openDailyNoteDirect(id: String = "", title: String = "", open: Bool = true, show: Bool = true) {
        
        let open = open == true ? "yes" : "no"
        let show = show == true ? "yes" : "no"
        
        let successCallback = "fodabear://open-daily-note-success"
        let errorCallback = "fodabear://open-daily-note-error"
        let openNoteURLString = "bear://x-callback-url/open-note?title=\(title)&open_note=\(open)&show_window=\(show)&exclude_trashed=yes&x-success=\(successCallback)&x-error=\(errorCallback)"
        
        print("open note url: \(openNoteURLString)")
        
        openURL(openNoteURLString)
    }
    
    
    func openNoteDirect(id: String = "", title: String = "", open: Bool = true, show: Bool = true) {
        
        let open = open == true ? "yes" : "no"
        let show = show == true ? "yes" : "no"
        
        let openNoteURLString = "bear://x-callback-url/open-note?title=\(title)&open_note=\(open)&show_window=\(show)&exclude_trashed=yes"
        
        print("open note url: \(openNoteURLString)")
        
        openURL(openNoteURLString)
    }
    
    
    func createNoteDirect(title: String?, content: String, tags: [String], open: Bool) {
        
        let successCallback = "fodabear://create-note-success"
        let errorCallback = "fodabear://create-note-error"
        let createURLString = "bear://x-callback-url/create?title=\(title ?? "")&text=\(content)&tags=\(tags.joined(separator: ","))&open_note=\(open)&show_window=\(open)&x-success=\(successCallback)&x-error=\(errorCallback)"
        
        openURL(createURLString)
    }
    
    func openNote(id: String = "", title: String = "", open: Bool = true, show: Bool = true, completion: @escaping (Result<String, Error>) -> Void) {
        
        let open = open == true ? "yes" : "no"
        let show = show == true ? "yes" : "no"
        
        let successCallback = "fodabear://openNoteSuccess"
        let errorCallback = "fodabear://openNoteError"
        let openNoteURLString = "bear://x-callback-url/open-note?title=\(title)&open_note=\(open)&show_window=\(show)&x-success=\(successCallback)&x-error=\(errorCallback)&exclude_trashed=yes"
        
        print("open note url: \(openNoteURLString)")
        
        openURL(openNoteURLString)
    }
    
    func create(title: String?, content: String, tags: [String], open: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        self.createCompletion = completion
        let successCallback = "fodabear://createNoteSuccess"
        let errorCallback = "fodabear://createNoteError"
        let createURLString = "bear://x-callback-url/create?title=\(title ?? "")&text=\(content)&tags=\(tags.joined(separator: ","))&open_note=\(open)&show_window=\(open)&x-success=\(successCallback)&x-error=\(errorCallback)"
        
        
        print("create_url: \(createURLString)")
        
        
        openURL(createURLString)
    }
    
    public func openURL(_ urlString: String) {
        if let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func handleSearchSuccess(url: URL) {
        let notes = parseNotes(from: url)
        searchCompletion?(.success(notes))
    }
    
    private func handleSearchError(url: URL) {
        searchCompletion?(.failure(NSError(domain: "searchError", code: 1, userInfo: nil)))
    }
    
    private func handleOpenNoteSuccess(url: URL) {
        print("open success")
        
    }
    
    private func handleOpenNoteError(url: URL) {
        print("open error")
    }
    
    
    private func handleOpenDailyNoteSuccess(url: URL) {
        print("open success")
    }
    
    private func handleOpenDailyNoteError(url: URL) {
        NoteHandler.shared.createDailyNoteWithDate(DateUtils.getCurrentDateFormatted())
    }
    
    private func handleCreateNoteSuccess(url: URL) {
        print("create note success")
    }
    
    private func handleCreateNoteError(url: URL) {
        print("create_note_url_error: \(url)")
    }
    
    private func parseNotes(from url: URL) -> [String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return []
        }
        
        guard let notesItem = queryItems.first(where: { $0.name == "notes" }),
              let notesData = notesItem.value?.data(using: .utf8) else {
            return []
        }
        
        do {
            if let notesArray = try JSONSerialization.jsonObject(with: notesData, options: []) as? [[String: Any]] {
                return notesArray.compactMap { $0["identifier"] as? String }
            }
        } catch {
            print("Error decodificando el JSON: \(error)")
            return []
        }
        
        return []
    }
    
    private func parseNoteId(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "identifier" })?.value
    }
    
    private func parseNoteContent(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        return components.queryItems?.first(where: { $0.name == "note" })?.value
    }
}
