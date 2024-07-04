import Cocoa
import SwiftUI
import ServiceManagement
import EventKit


class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var statusItem: NSStatusItem!
    @Published var settingsWindowController: NSWindowController?
    @Published var currentTodayDateString: String?
    @Published var currentHomeNoteID: String?
    @Published var currentDailyNoteID: String?
    @Published var popover: NSPopover?
    @Published var aboutPopover: NSPopover?
    private var aboutPopoverTransiencyMonitor: Any?
    let noteManager = NoteManager.shared
    let settingsManager = SettingsManager.shared
    let calendarSyncManager = CalendarSyncManager()
    @Published var noteContent: String?
    private var semaphore = DispatchSemaphore(value: 0)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        configureLaunchAtLogin()
        requestCalendarAccess()
    }
    
    func resetLaunchAtLoginState() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                print("Launch at login has been reset to disabled")
            }
        } catch {
            print("Failed to reset launch at login status: \(error.localizedDescription)")
        }
    }
    
    func handleCallback(url: URL) {
        if let host = url.host {
            switch host {
            case "update-home-note-if-needed-success":
                updateHomeNoteIfNeededSuccess(url: url)
            case "update-home-note-if-needed-error":
                updateHomeNoteIfNeededError(url: url)
            case "update-daily-note-if-needed-success":
                updateDailyNoteIfNeededSuccess(url: url)
            case "update-daily-note-if-needed-success-for-sync":
                updateDailyNoteIfNeededSuccessForSync(url: url)
            case "update-daily-note-if-needed-error":
                updateDailyNoteIfNeededError(url: url)
            case "open-daily-note-success":
                openDailyNoteSuccess(url: url)
            case "open-daily-note-error":
                openDailyNoteError(url: url)
            default:
                break
            }
        }
    }
    

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(isDarkMode() ? "bear_paw_icon_dark" : "bear_paw_icon_light"))
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func configureLaunchAtLogin() {
        resetLaunchAtLoginState()
        let launchAtLogin = settingsManager.launchAtLogin
        print("Configuring launch at login: \(launchAtLogin)")
        settingsManager.setLaunchAtLogin(enabled: launchAtLogin)
    }

    private func requestCalendarAccess() {
        noteManager.calendarManager.requestAccess { [weak self] granted in
            guard let self = self else { return }
            if granted {
                print("Calendar access granted")
                self.calendarSyncManager.scheduleCalendarUpdates()
            } else {
                print("Access to calendar not granted")
            }
        }
    }

    @objc func handleClick() {
        print("Status bar item clicked")
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            executeDefaultAction()
        }
    }
    
    private func executeDefaultAction() {
        let defaultAction = settingsManager.defaultAction
        print("Executing default action: \(defaultAction)")
        switch defaultAction {
        case "home":
            openHomeNote()
        case "daily":
            openDailyNote()
        default:
            print("Left click action is disabled")
        }
    }

    private func showMenu() {
        print("Showing menu")
        let menu = NSMenu()
        
        addMenuItem(to: menu, title: "Open Home Note", action: #selector(openHomeNote), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        addMenuItem(to: menu, title: "Open Daily Note", action: #selector(openDailyNote), keyEquivalent: "")
        addMenuItem(to: menu, title: "Create Custom Daily Note", action: #selector(showDatePicker), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        addCustomTemplateItems(to: menu)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(to: menu, title: "Sync Calendar Events", action: #selector(syncNow), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        addMenuItem(to: menu, title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        addMenuItem(to: menu, title: "About", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        addMenuItem(to: menu, title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.statusItem.menu = nil
            self?.restoreLeftClickAction()
        }
    }

    private func addMenuItem(to menu: NSMenu, title: String, action: Selector, keyEquivalent: String) {
        menu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent))
    }

    private func addCustomTemplateItems(to menu: NSMenu) {
        let templates = settingsManager.loadTemplates()
        for template in templates where !template.isDaily {
            addMenuItem(to: menu, title: "Create \(template.name) Note", action: #selector(openTemplateNote(_:)), keyEquivalent: "")
        }
    }

    @objc func showAbout() {
        print("Showing about popover")
        if aboutPopover == nil {
            aboutPopover = NSPopover()
            aboutPopover?.contentViewController = NSHostingController(rootView: AboutPopoverView())
            aboutPopover?.behavior = .transient
        }
        if let button = statusItem.button {
            aboutPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            aboutPopoverTransiencyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closeAboutPopover()
            }
        }
    }

    private func closeAboutPopover() {
        if aboutPopover?.isShown == true {
            aboutPopover?.performClose(nil)
            if let monitor = aboutPopoverTransiencyMonitor {
                NSEvent.removeMonitor(monitor)
                aboutPopoverTransiencyMonitor = nil
            }
        }
    }
    
    @objc func openAbout() {
        print("Opening About window")
        let aboutView = AboutPopoverView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentView = NSHostingView(rootView: aboutView)
        window.title = "About"
        let aboutWindowController = NSWindowController(window: window)
        aboutWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        print("Opening settings")
        if settingsWindowController == nil {
            createSettingsWindow()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createSettingsWindow() {
        print("Creating settings window")
        let settingsView = SettingsView()
            .environmentObject(self)
            .environmentObject(noteManager.calendarManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentView = NSHostingView(rootView: settingsView)
        window.title = "Settings"
        settingsWindowController = NSWindowController(window: window)
    }

    @objc func openHomeNote() {
        print("Opening home note")

        let homeNoteID = settingsManager.homeNoteID
        self.updateHomeNoteIfNeeded()
        if let url = URL(string: "bear://x-callback-url/open-note?id=\(homeNoteID)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    @objc func syncNow() {
        let calendar = Calendar.current
        let today = Date()
        
        for i in -7...7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let formattedDate = getCurrentDateFormatted(date: date)
                self.syncCalendarForDate(formattedDate)
            }
        }
        
        
        
        
    }
    
    func syncCalendarForDate(_ date: String?) {
        
        
        let date = date ?? getCurrentDateFormatted()
        
        let fetchURLString = "bear://x-callback-url/open-note?title=\(date)&show_window=no&open_note=no&x-success=fodabear://update-daily-note-if-needed-success-for-sync"
        if let fetchURL = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            print("Fetching daily note with URL: \(fetchURL)")
            NSWorkspace.shared.open(fetchURL)
        }
    }
    
    
    
    
    
    
    
    func updateHomeNoteIfNeeded() {
        
        let homeNoteId = SettingsManager.shared.homeNoteID
        let currentDateFormatted = self.getCurrentDateFormatted()
        let fetchURLString = "bear://x-callback-url/open-note?id=\(homeNoteId)&show_window=no&open_note=no&x-success=fodabear://update-home-note-if-needed-success&x-error=fodabear://update-home-note-if-needed-error"
        if let fetchURL = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            print("Fetching home note with URL: \(fetchURL)")
            NSWorkspace.shared.open(fetchURL)
        }
    }
    
    func updateDailyNoteIfNeeded(_ date: String?) {
        
    
        let currentDateFormatted = self.getCurrentDateFormatted()
        let fetchURLString = "bear://x-callback-url/open-note?title=\(currentDateFormatted)&show_window=no&open_note=no&x-success=fodabear://update-daily-note-if-needed-success&x-error=fodabear://update-daily-note-if-needed-error"
        if let fetchURL = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            print("Fetching daily note with URL: \(fetchURL)")
            NSWorkspace.shared.open(fetchURL)
        }
    }
    
    private func updateDailyNoteIfNeededError(url: URL) {}
    
    
    
    private func updateDailyNoteIfNeededSuccess(url: URL) {
        
      
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        guard let title = queryItems.first(where: { $0.name == "title" })?.value else {
            let title = ""
            return
        }
        
        guard let note = queryItems.first(where: { $0.name == "note" })?.value else {
            let note = ""
            return
        }
        
        guard let id = queryItems.first(where: { $0.name == "identifier" })?.value else {
            let id = ""
            return
        }
        
        NoteManager.shared.updateDailyNoteWithCalendarEvents(for: title,noteContent: note, noteId: id)
    }
    
    private func updateDailyNoteIfNeededSuccessForSync(url: URL) {
        
      
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        guard let title = queryItems.first(where: { $0.name == "title" })?.value else {
            let title = ""
            return
        }
        
        guard let note = queryItems.first(where: { $0.name == "note" })?.value else {
            let note = ""
            return
        }
        
        guard let id = queryItems.first(where: { $0.name == "identifier" })?.value else {
            let id = ""
            return
        }
        
        NoteManager.shared.updateDailyNoteWithCalendarEvents(for: title,noteContent: note, noteId: id, open: false)
    }
    
    
    
    private func updateHomeNoteIfNeededSuccess(url: URL) {
        let homeNoteId = SettingsManager.shared.homeNoteID
        let currentDateFormatted = self.getCurrentDateFormatted()
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        guard let note = queryItems.first(where: { $0.name == "note" })?.value else {
            let note = ""
            return
        }
        
        NoteManager.shared.updateHomeNoteWithCalendarEvents(for: currentDateFormatted,noteContent: note, homeNoteId: homeNoteId)
    }
    
    private func updateHomeNoteIfNeededError(url: URL) {

            print("updateHomeNoteIfNeededError: \(url)")

    }
    
    

    

    
    
    
       @objc func openDailyNoteWithDate(_ date: String?) {
           print("Opening daily note")

           
           let date = date ?? getCurrentDateFormatted()
           
           let successParameter = "fodabear://open-daily-note-with-date-success"
           let errorParameter = "fodabear://open-daily-note-with-date-error?date=\(date)"
           
           self.updateDailyNoteIfNeeded(date)
           if let dailyUrl = URL(string: "bear://x-callback-url/open-note?title=\(date)&open_note=no&show_window=no&exclude_trashed=yes&x-success=\(successParameter)&x-error=\(errorParameter)") {
               NSWorkspace.shared.open(dailyUrl)
           }
           
       }
 
    
    @objc func openDailyNote() {
        print("Opening daily note")
        let dateToday = getCurrentDateFormatted()
        
        let successParameter = "fodabear://open-daily-note-success"
        let errorParameter = "fodabear://open-daily-note-error"
        
        self.updateDailyNoteIfNeeded(dateToday)
        if let dailyUrl = URL(string: "bear://x-callback-url/open-note?title=\(dateToday)&open_note=no&show_window=no&exclude_trashed=yes&x-success=\(successParameter)&x-error=\(errorParameter)") {
            NSWorkspace.shared.open(dailyUrl)
        }
        
    }
    
    @objc func openDailyNoteSuccess(url: URL) {
        
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            
            
            let dailyId = queryItems.first(where: { $0.name == "id" })?.value
            if let dailyUrl = URL(string: "bear://x-callback-url/open-note?id=\(String(describing: dailyId))") {
                NSWorkspace.shared.open(dailyUrl)
            }
        }
    }
    
    @objc func openDailyNoteError(url: URL) {
        
        self.createDailyNoteWithDate(self.getCurrentDateFormatted())
        
    }
    
    
    
    @objc func openDailyNoteWithDateSuccess(url: URL) {
        
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            
            
            let dailyId = queryItems.first(where: { $0.name == "id" })?.value
            if let dailyUrl = URL(string: "bear://x-callback-url/open-note?id=\(String(describing: dailyId))") {
                NSWorkspace.shared.open(dailyUrl)
            }
        }
    }
    
    @objc func openDailyNoteWithDateError(url: URL) {
        
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            
            
            let dailyDate = queryItems.first(where: { $0.name == "date" })?.value
            self.createDailyNoteWithDate(dailyDate)

        }
        
        
    }
    

    

    @objc func showDatePicker() {
        if popover == nil {
            popover = NSPopover()
            popover?.contentViewController = NSHostingController(rootView: CalendarPopoverView(onSelectDate: { [weak self] (selectedDate: Date) in
                self?.popover?.performClose(nil)
                let selectedDateString = self?.getCurrentDateFormatted(date: selectedDate)
                self?.createDailyNoteWithDate(selectedDateString)
            }))
            popover?.behavior = .transient
        }

        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "fodabear" {
                self.handleCallback(url: url)
            }
        }
    }

    private func handleOpenNoteSuccess(url: URL) {
        print("URL received: \(url)")
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let noteContent = queryItems.first(where: { $0.name == "note" })?.value,
              let todayDateString = self.currentTodayDateString,
              let homeNoteID = self.currentHomeNoteID else {
            print("Error: Missing required query items or context values")
            return
        }
        
        print("Note content found: \(noteContent)")
        print("Current today date string: \(todayDateString)")
        print("Current home note ID: \(homeNoteID)")
        handleOpenNoteSuccess(noteContent: noteContent, todayDateString: todayDateString, homeNoteID: homeNoteID)
    }

    private func handleOpenNoteDailySuccess(url: URL) {
        print("Daily note already exists. URL received: \(url)")
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let noteContent = queryItems.first(where: { $0.name == "note" })?.value,
              let todayDateString = self.currentTodayDateString,
              let dailyNoteID = self.currentDailyNoteID else {
            print("Error: Missing required query items or context values")
            return
        }
        
        print("Note content found: \(noteContent)")
        print("Current today date string: \(todayDateString)")
        print("Current daily note ID: \(dailyNoteID)")
        handleOpenNoteSuccess(noteContent: noteContent, todayDateString: todayDateString, homeNoteID: dailyNoteID)
    }

    private func handleOpenNoteSuccess(noteContent: String, todayDateString: String, homeNoteID: String) {
        print("Handling open note success")
        print("Note content: \(noteContent)")
        print("Today date string: \(todayDateString)")
        print("Home note ID: \(homeNoteID)")
        let updatedContent = noteManager.replaceCalendarSection(in: noteContent, with: "## Eventos\n\(noteManager.fetchCalendarEvents(for: todayDateString))")
        print("Updated content: \(updatedContent)")
        noteManager.updateHomeNoteContent(newContent: updatedContent, homeNoteID: homeNoteID)
    }

    private func isDarkMode() -> Bool {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func restoreLeftClickAction() {
        if let button = statusItem.button {
            print("Restoring left click action")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    func openTemplateNote(for templateName: String) -> Template? {
        guard let template = settingsManager.loadTemplates().first(where: { $0.name == templateName }) else {
            print("Template not found")
            return nil
        }
        
        noteManager.openTemplate(template)
        return template
    }

    @objc func openTemplateNote(_ sender: NSMenuItem) {
        let templateTitle = sender.title
        let templateNameComponents = templateTitle.components(separatedBy: " ")

        guard templateNameComponents.count > 2 else { return }

        let templateName = templateNameComponents.dropFirst().dropLast().joined(separator: " ")

        guard let template = settingsManager.loadTemplates().first(where: { $0.name == templateName }) else { return }

        noteManager.openTemplate(template)
        
    }
    
    
    
    
    
    func createDailyNoteWithDate(_ date: String?) {
        
        let date = date ?? getCurrentDateFormatted()
        
        guard let template = SettingsManager.shared.loadTemplates().first(where: { $0.name == "Daily" }) else { return }
        
        let processedContent = NoteManager.shared.processTemplateVariables(template.content,for: date)
        
        let tags = [template.tag]
        
        // Codificación de URL para crear la nota
        let createURLString = "bear://x-callback-url/create?text=\(processedContent.addingPercentEncodingForRFC3986() ?? "")&tags=\(tags.joined(separator: ",").addingPercentEncodingForRFC3986() ?? "")&open_note=yes&show_window=yes"
        
        // Codificación de URL para abrir la nota
        let openURLString = "bear://x-callback-url/open-note?title=\(date.addingPercentEncodingForRFC3986() ?? "")&open_note=yes&show_window=yes"
        
        // Codificación de URL para fetch con x-success y x-error codificados
        let fetchURLString = "bear://x-callback-url/open-note?title=\(date.addingPercentEncodingForRFC3986() ?? "")&open_note=no&show_window=no&exclude_trashed=yes&x-success=\(openURLString.addingPercentEncodingForRFC3986() ?? "")&x-error=\(createURLString.addingPercentEncodingForRFC3986() ?? "")"
        
        
        if let fetchURL = URL(string: fetchURLString) {
           
            NSWorkspace.shared.open(fetchURL)
        }
        
    }
    
    
    
    func getCurrentDateFormatted(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    
}
