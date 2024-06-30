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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(isDarkMode() ? "bear_paw_icon_dark" : "bear_paw_icon_light"))
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func configureLaunchAtLogin() {
        let launchAtLogin = settingsManager.launchAtLogin
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
        
        addMenuItem(to: menu, title: "Open Home Note", action: #selector(openHomeNote), keyEquivalent: "H")
        menu.addItem(NSMenuItem.separator())
        addMenuItem(to: menu, title: "Open Daily Note", action: #selector(openDailyNote), keyEquivalent: "D")
        addMenuItem(to: menu, title: "Create Custom Daily Note", action: #selector(showDatePicker), keyEquivalent: "C")
        menu.addItem(NSMenuItem.separator())
        
        addCustomTemplateItems(to: menu)
        menu.addItem(NSMenuItem.separator())
        
        addMenuItem(to: menu, title: "Settings", action: #selector(openSettings), keyEquivalent: "S")
        addMenuItem(to: menu, title: "About", action: #selector(openAbout), keyEquivalent: "A")
        menu.addItem(NSMenuItem.separator())
        addMenuItem(to: menu, title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "Q")

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
        if let url = URL(string: "bear://x-callback-url/open-note?id=\(homeNoteID)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    @objc func openDailyNote() {
        print("Opening daily note")
        
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        
        self.currentTodayDateString = dateString
        
        let homeNoteID = settingsManager.homeNoteID
        if !homeNoteID.isEmpty {
            noteManager.updateHomeNoteIfNeeded(homeNoteID: homeNoteID, todayDateString: dateString)
        }
        
        
        
        let titleParameter = dateString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let successParameter = "fodabear://open-note-daily-success".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let errorParameter = "fodabear://open-note-daily-error".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let openNoteURLString = "bear://x-callback-url/open-note?title=\(titleParameter)&exclude_trashed=yes&x-success=\(successParameter)&x-error=\(errorParameter)"
        
        if let openNoteURL = URL(string: openNoteURLString) {
            print("Opening note with URL: \(openNoteURL)")
            NSWorkspace.shared.open(openNoteURL)
            noteManager.updateDailyNoteWithCalendarEvents(for: dateString)
        } else {
            print("Failed to create URL from string: \(openNoteURLString)")
        }
        
//        if let openNoteURL = URL(string: openNoteURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
//            print("Opening note with URL: \(openNoteURL)")
//            NSWorkspace.shared.open(openNoteURL)
//            noteManager.getDailyNoteID(for: dateString) { [weak self] dailyNoteID in
//                guard let self = self else { return }
//                self.currentDailyNoteID = dailyNoteID
//                if !dailyNoteID.isEmpty {
//                    self.noteManager.updateDailyNoteWithCalendarEvents(for: dateString)
//                }
//            }
//        }
    }
    
    
    
    

    @objc func showDatePicker() {
        if popover == nil {
            popover = NSPopover()
            popover?.contentViewController = NSHostingController(rootView: CalendarPopoverView(onSelectDate: { [weak self] (selectedDate: Date) in
                self?.popover?.performClose(nil)
                self?.noteManager.createDailyNoteForDate(selectedDate: selectedDate)
            }))
            popover?.behavior = .transient
        }

        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            print("URL scheme: \(url.scheme ?? "nil")")
            print("URL host: \(url.host ?? "nil")")
            print("URL received: \(url.absoluteString)")

            if url.scheme == "fodabear" {
                if url.host == "open-note-success" {
                    print("URL received: \(url)")
                    if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                        print("Query items: \(queryItems)")
                        if let noteContent = queryItems.first(where: { $0.name == "note" })?.value,
                           let todayDateString = self.currentTodayDateString,
                           let homeNoteID = self.currentHomeNoteID {
                            print("Note content found: \(noteContent)")
                            print("Current today date string: \(todayDateString)")
                            print("Current home note ID: \(homeNoteID)")
                            handleOpenNoteSuccess(noteContent: noteContent, todayDateString: todayDateString, homeNoteID: homeNoteID)
                        } else {
                            print("Error: Missing required query items or context values")
                        }
                    }
                } else if url.host == "open-note-daily-success" {
                    print("Daily note already exists. URL received: \(url)")
                } else if url.host == "open-note-daily-error" {
                    print("Open note error received: \(url)")
                    noteManager.createDailyNoteWithTemplate(for: currentTodayDateString ?? "")
                } else if url.host == "open-note-error" {
                    print("Open note error received: \(url)")
                }
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

    @objc func openTemplateNote(_ sender: NSMenuItem) {
        let templateTitle = sender.title
        let templateNameComponents = templateTitle.components(separatedBy: " ")

        guard templateNameComponents.count > 2 else { return }

        let templateName = templateNameComponents.dropFirst().dropLast().joined(separator: " ")

        guard let template = settingsManager.loadTemplates().first(where: { $0.name == templateName }) else { return }

        noteManager.openTemplate(template)
    }
}
