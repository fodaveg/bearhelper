import Cocoa
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindowController: NSWindowController?
    var currentTodayDateString: String?
    var currentHomeNoteID: String?
    var popover: NSPopover?
    var aboutPopover: NSPopover?
    var aboutPopoverTransiencyMonitor: Any?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(isDarkMode() ? "bear_paw_icon_dark" : "bear_paw_icon_light"))
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        setLaunchAtLogin(enabled: launchAtLogin)
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
    
    func executeDefaultAction() {
        let defaultAction = UserDefaults.standard.string(forKey: "defaultAction") ?? "disabled"
        print("Executing default action: \(defaultAction)")
        if defaultAction == "home" {
            openHomeNote()
        } else if defaultAction == "daily" {
            openDailyNote()
        } else {
            print("Left click action is disabled")
        }
    }

    func showMenu() {
        print("Showing menu")
        let menu = NSMenu()

        // Home Note
        menu.addItem(NSMenuItem(title: "Open Home Note", action: #selector(openHomeNote), keyEquivalent: "H"))
        menu.addItem(NSMenuItem.separator())

        // Daily Note
        menu.addItem(NSMenuItem(title: "Open Daily Note", action: #selector(openDailyNote), keyEquivalent: "D"))
        menu.addItem(NSMenuItem(title: "Create Custom Daily Note", action: #selector(showDatePicker), keyEquivalent: "C"))
        menu.addItem(NSMenuItem.separator())

        // Custom Templates
        let templates = loadTemplates()
        for template in templates where !template.isDaily {
            menu.addItem(NSMenuItem(title: "Create \(template.name) Note", action: #selector(openTemplateNote(_:)), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem.separator())

        // Settings and About
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "S"))
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "A"))
        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "Q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.statusItem.menu = nil
            self.restoreLeftClickAction()
        }
    }

    @objc func showAbout() {
        print("Showing about popover")
        if aboutPopover == nil {
            let popover = NSPopover()
            popover.contentViewController = NSHostingController(rootView: AboutPopoverView())
            popover.behavior = .transient
            self.aboutPopover = popover
        }
        if let button = statusItem.button {
            aboutPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            aboutPopoverTransiencyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closeAboutPopover()
            }
        }
    }

    func closeAboutPopover() {
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

    @objc func openHomeNote() {
        print("Opening home note")
        let homeNoteID = UserDefaults.standard.string(forKey: "homeNoteID") ?? ""
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
        
        let homeNoteID = UserDefaults.standard.string(forKey: "homeNoteID") ?? ""
        if !homeNoteID.isEmpty {
            updateHomeNoteIfNeeded(homeNoteID: homeNoteID, todayDateString: dateString)
        }
        
        self.currentTodayDateString = dateString
        let openNoteURLString = "bear://x-callback-url/open-note?title=\(dateString)&exclude_trashed=yes&x-success=fodabear://open-note-daily-success&x-error=fodabear://open-note-daily-error"
        if let openNoteURL = URL(string: openNoteURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
            print("Opening note with URL: \(openNoteURL)")
            NSWorkspace.shared.open(openNoteURL)
        }
    }

    @objc func showDatePicker() {
        if popover == nil {
            popover = NSPopover()
            popover?.contentViewController = NSHostingController(rootView: CalendarPopoverView(onSelectDate: { (selectedDate: Date) in
                self.popover?.performClose(nil)
                self.createDailyNoteForDate(selectedDate: selectedDate)
            }))
            popover?.behavior = .transient
        }

        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    func createDailyNoteForDate(selectedDate: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)

        self.currentTodayDateString = dateString

        let openNoteURLString = "bear://x-callback-url/open-note?title=\(dateString)&exclude_trashed=yes&x-success=fodabear://open-note-daily-success&x-error=fodabear://open-note-daily-error"
        if let openNoteURL = URL(string: openNoteURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
            print("Opening note with URL: \(openNoteURL)")
            NSWorkspace.shared.open(openNoteURL)
        }
    }

    func createDailyNoteWithTemplate(for dateString: String) {
        let tag = UserDefaults.standard.string(forKey: "dailyNoteTag") ?? ""
        let template = UserDefaults.standard.string(forKey: "dailyNoteTemplate") ?? ""
        
        let processedTemplate = processTemplate(template, for: dateString)
        let encodedTemplate = processedTemplate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var urlString = "bear://x-callback-url/create?title=&text=\(encodedTemplate)"
        if !tag.isEmpty {
            let encodedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString += "&tags=\(encodedTag)"
        }
        if let url = URL(string: urlString) {
            print("Creating note with URL: \(url)")
            NSWorkspace.shared.open(url)
        }
        
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if dateString == todayString {
                let homeNoteID = UserDefaults.standard.string(forKey: "homeNoteID") ?? ""
                if !homeNoteID.isEmpty {
                    self.updateHomeNoteIfNeeded(homeNoteID: homeNoteID, todayDateString: dateString)
                }
            }
        }
    }

    func processTemplate(_ template: String, for dateString: String) -> String {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: "%date\\(([-+]?\\d*)\\)%", options: [])
        } catch {
            print("Regex pattern error: \(error.localizedDescription)")
            return template
        }

        let matches = regex.matches(in: template, options: [], range: NSRange(template.startIndex..., in: template))

        var processedTemplate = template
        for match in matches.reversed() {
            let matchRange = match.range(at: 0)
            let daysRange = match.range(at: 1)

            let daysString = (template as NSString).substring(with: daysRange)
            let days = Int(daysString) ?? 0

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.date(from: dateString) ?? Date()
            let targetDate = Calendar.current.date(byAdding: .day, value: days, to: today)!
            let targetDateString = formatter.string(from: targetDate)

            processedTemplate = (processedTemplate as NSString).replacingCharacters(in: matchRange, with: targetDateString)
        }

        return processedTemplate
    }


    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "fodabear" {
                if url.host == "open-note-success" {
                    print("URL received: \(url)")
                    if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                        if let noteContent = queryItems.first(where: { $0.name == "note" })?.value,
                           let todayDateString = self.currentTodayDateString,
                           let homeNoteID = self.currentHomeNoteID {
                            print("Note content received: \(noteContent)")
                            handleOpenNoteSuccess(noteContent: noteContent, todayDateString: todayDateString, homeNoteID: homeNoteID)
                        }
                    }
                } else if url.host == "open-note-daily-success" {
                    print("Daily note already exists. URL received: \(url)")
                } else if url.host == "open-note-daily-error" {
                    print("Open note error received: \(url)")
                    createDailyNoteWithTemplate(for: currentTodayDateString ?? "")
                } else if url.host == "open-note-error" {
                    print("Open note error received: \(url)")
                }
            }
        }
    }

    func updateHomeNoteIfNeeded(homeNoteID: String, todayDateString: String) {
        self.currentTodayDateString = todayDateString
        self.currentHomeNoteID = homeNoteID

        let fetchURLString = "bear://x-callback-url/open-note?id=\(homeNoteID)&show_window=no&open_note=no&x-success=fodabear://open-note-success&x-error=fodabear://open-note-error"
        if let fetchURL = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
            print("Fetching home note with URL: \(fetchURL)")
            NSWorkspace.shared.open(fetchURL)
        }
    }
    
    func handleOpenNoteSuccess(noteContent: String, todayDateString: String, homeNoteID: String) {
        let cleanedNoteContent = noteContent.replacingOccurrences(of: "\u{FFFC}", with: "")
        let regexPattern = "(?m)^## Daily\\n[-*] {1,2}\\[\\[\\d{4}-\\d{2}-\\d{2}\\]\\]$"
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: regexPattern)
        } catch {
            print("Regex pattern error: \(error.localizedDescription)")
            return
        }
        let range = NSRange(location: 0, length: cleanedNoteContent.utf16.count)
        
        if let match = regex.firstMatch(in: cleanedNoteContent, options: [], range: range) {
            let matchedStringRange = match.range(at: 0)
            if let swiftRange = Range(matchedStringRange, in: cleanedNoteContent) {
                let matchedString = cleanedNoteContent[swiftRange]
                let updatedString = matchedString.replacingOccurrences(of: "\\d{4}-\\d{2}-\\d{2}", with: todayDateString, options: .regularExpression)
                let newNoteContent = cleanedNoteContent.replacingCharacters(in: swiftRange, with: updatedString)
                updateHomeNoteContent(newContent: newNoteContent, homeNoteID: homeNoteID)
            }
        } else {
            print("No match found in note content.")
            let newDailyEntry = "## Daily\n- [[\(todayDateString)]]"
            let newNoteContent = cleanedNoteContent + "\n\n" + newDailyEntry
            updateHomeNoteContent(newContent: newNoteContent, homeNoteID: homeNoteID)
        }
    }
    
    @objc func openSettings() {
        print("Opening settings")
        if settingsWindowController == nil {
            createSettingsWindow()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createSettingsWindow() {
        print("Creating settings window")
        let settingsView = SettingsView(setLaunchAtLogin: setLaunchAtLogin)
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

    @objc func interfaceModeChanged() {
        if let button = statusItem.button {
            let imageName = isDarkMode() ? "bear_paw_icon_dark" : "bear_paw_icon_light"
            button.image = NSImage(named: imageName)
        }
    }

    func isDarkMode() -> Bool {
        let appearance = NSApp.effectiveAppearance
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua
    }
    
    func updateHomeNoteContent(newContent: String, homeNoteID: String) {
        if let encodedContent = newContent.addingPercentEncodingForRFC3986() {
            if let url = URL(string: "bear://x-callback-url/add-text?open_note=no&new_window=no&show_window=no&id=\(homeNoteID)&mode=replace_all&text=\(encodedContent)") {
                print("Updating home note with URL: \(url)")
                NSWorkspace.shared.open(url)
            }
        } else {
            print("Failed to encode new content for URL.")
        }
    }

    func restoreLeftClickAction() {
        if let button = statusItem.button {
            print("Restoring left click action")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func setLaunchAtLogin(enabled: Bool) {
        let launcherAppIdentifier = "net.fodaveg.bearhelperlauncher"
        
        do {
            if enabled {
                if SMAppService.mainApp.status == .notRegistered {
                    try SMAppService.mainApp.register()
                    print("Successfully set launch at login")
                } else {
                    print("Launch at login is already enabled")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("Successfully unset launch at login")
                } else {
                    print("Launch at login is already disabled")
                }
            }
        } catch {
            print("Failed to update launch at login status: \(error.localizedDescription)")
        }
    }
    
    @objc func openTemplateNote(_ sender: NSMenuItem) {
        let templateTitle = sender.title
        let templateNameComponents = templateTitle.components(separatedBy: " ")
        
        guard templateNameComponents.count > 2 else {
            return
        }
        
        let templateName = templateNameComponents.dropFirst().dropLast().joined(separator: " ")
        
        guard let template = loadTemplates().first(where: { $0.name == templateName }) else {
            return
        }
        
        openTemplate(template)
    }
    
    func openTemplate(_ template: Template) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let processedTemplate = processTemplate(template.content, for: dateString)
        let encodedTemplate = processedTemplate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        var urlString = "bear://x-callback-url/create?title=&text=\(encodedTemplate)"
        if !template.tag.isEmpty {
            let encodedTag = template.tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString += "&tags=\(encodedTag)"
        }

        if let url = URL(string: urlString) {
            print("Creating note with URL: \(url)")
            NSWorkspace.shared.open(url)
        }
    }
    
    private func loadTemplates() -> [Template] {
        var templates: [Template] = []
        
        if let templatesData = UserDefaults.standard.data(forKey: "templates"),
           let loadedTemplates = try? JSONDecoder().decode([Template].self, from: templatesData) {
            templates = loadedTemplates
        }
        
        // Asegurarse de que la plantilla "Daily" siempre exista
        if !templates.contains(where: { $0.isDaily }) {
            let dailyTemplateContent = """
            ---
            type: daily
            date: %date()%
            ---
            # %date()%
            
            
            
            
            
            
            
            <- [[%date(-1)%]] - [[%date(+1)%]] ->
            ---
            """
            let dailyTemplate = Template(name: "Daily", content: dailyTemplateContent, tag: "Daily Notes", isDaily: true)
            templates.append(dailyTemplate)
            saveTemplates(templates)
        }
        
        return templates
    }

    private func saveTemplates(_ templates: [Template]) {
        if let templatesData = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(templatesData, forKey: "templates")
        }
    }
}


