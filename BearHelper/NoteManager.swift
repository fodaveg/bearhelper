import Foundation
import AppKit
import EventKit

class NoteManager: ObservableObject {
    public static let shared = NoteManager()
    var calendarManager = CalendarManager()
    
    private init() {}  // Singleton Pattern

    var noteContent: String? // Variable para almacenar el contenido de la nota
    let semaphore = DispatchSemaphore(value: 0) // Semáforo para la sincronización

    func createDailyNoteForDate(selectedDate: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)

        let dailyNoteID: () = getDailyNoteID(for: dateString) { noteContent in
            if noteContent.isEmpty {
                self.createDailyNoteWithTemplate(for: dateString)
            } else {
                //self.updateDailyNoteWithCalendarEvents(for: dateString)
            }
        }
    }
    
    
    func replaceDateOnHome(_ id: String) {
        // Reemplazar la fecha en la nota del home
    }

    func updateCalendarEventsOnNote(_ noteId: String) {
        // Actualizar los eventos del calendario en la nota especificada
        
       
        
    }

  
        func processTemplateVariables(_ content: String, for dateString: String) -> String {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: "%date\\(([-+]?\\d*)\\)%", options: [])
            } catch {
                print("Regex pattern error: \(error.localizedDescription)")
                return content
            }

            let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

            var processedTemplate = content
            for match in matches.reversed() {
                let matchRange = match.range(at: 0)
                let daysRange = match.range(at: 1)

                let daysString = (content as NSString).substring(with: daysRange)
                let days = Int(daysString) ?? 0

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let today = formatter.date(from: dateString) ?? Date()
                let targetDate = Calendar.current.date(byAdding: .day, value: days, to: today)!
                let targetDateString = formatter.string(from: targetDate)

                processedTemplate = (processedTemplate as NSString).replacingCharacters(in: matchRange, with: targetDateString)
            }
            
            
            let updatedProcessedTemplate = replaceCalendarSection(in: processedTemplate, with: fetchCalendarEvents(for: dateString))
            
            return updatedProcessedTemplate
        }
    
    func convertToDate(from dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return dateFormatter.date(from: dateString)
    }
    
    

    func createDailyNoteWithTemplate(for dateString: String, with dailyTemplate: String? = "Daily") {
        
        print("template content: \(dailyTemplate)")
        let processedTemplate = processTemplate(dailyTemplate ?? "Daily", for: dateString)
        print(processedTemplate)
        print("processed template: \(processedTemplate)")
        let events = fetchCalendarEvents(for: dateString)
        print("events: \(events)")

        let replacedContent = replaceCalendarSection(in: processedTemplate, with: events)
        
        var urlString = "bear://x-callback-url/create?title=&text=\(processedTemplate)"
        if let tag = UserDefaults.standard.string(forKey: "dailyNoteTag"), !tag.isEmpty {
            urlString += "&tags=\(tag)"
        }

        if let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
            NSWorkspace.shared.open(url)
        }
    }

    func getHomeNoteContent(homeNoteID: String) -> String {
        // Implementar la lógica para obtener el contenido de la nota principal usando Bear x-callback-url
        return ""
    }

    func replaceCalendarSection(in content: String, with events: String) -> String {
        let calendarSectionHeader = UserDefaults.standard.string(forKey: "calendarSectionHeader") ?? "## Calendar Events"
        // Define el patrón de la expresión regular para capturar la sección del calendario y los eventos
        let pattern = "\(calendarSectionHeader)\\n(?:- \\[ \\] .*\\n|- \\[x\\] .*\\n)*"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])

            // Busca la primera coincidencia en el contenido
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)) {
                // Obtén los rangos antes y después de la coincidencia
                let range = Range(match.range, in: content)!
                let before = content[..<range.lowerBound]
                let after = content[range.upperBound...]
                // Devuelve el contenido con la sección reemplazada por los nuevos eventos
                return before + "\(calendarSectionHeader)\n" + events + "\n\(after)"
            } else {
                // Si no se encuentra la sección, añade los eventos al final del contenido
                return content + events
            }
        } catch {
            print("Error al crear la expresión regular: \(error.localizedDescription)")
            // En caso de error, devuelve el contenido original sin cambios
            return content
        }
    }

    func replaceDailySection(in content: String, with currentDate: String) -> String {
        //let calendarSectionHeader = UserDefaults.standard.string(forKey: "calendarSectionHeader") ?? "## Calendar Events"
        let dailySectionHeader = "## Daily"
        
        
        // Define el patrón de la expresión regular para capturar la sección del calendario y los eventos
        let pattern = "\(dailySectionHeader)\\n- \\[\\[\\d{4}-\\d{2}-\\d{2}\\]\\]"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])

            // Busca la primera coincidencia en el contenido
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)) {
                // Obtén los rangos antes y después de la coincidencia
                let range = Range(match.range, in: content)!
                let before = content[..<range.lowerBound]
                let after = content[range.upperBound...]
                // Devuelve el contenido con la sección reemplazada por los nuevos eventos
                return before + "\(dailySectionHeader)\n- [[\(currentDate)]]" + "\(after)"
            } else {
                // Si no se encuentra la sección, añade los eventos al final del contenido
                return content + "\(dailySectionHeader)\n- [[\(currentDate)]]"
            }
        } catch {
            print("Error al crear la expresión regular: \(error.localizedDescription)")
            // En caso de error, devuelve el contenido original sin cambios
            return content
        }
    }
    
    
    
    func updateHomeNoteIfNeeded(homeNoteID: String, todayDateString: String) {
        let fetchURLString = "bear://x-callback-url/open-note?id=\(homeNoteID)&show_window=no&open_note=no&x-success=fodabear://open-note-success&x-error=fodabear://open-note-error"
        if let fetchURL = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            print("Fetching home note with URL: \(fetchURL)")
            NSWorkspace.shared.open(fetchURL)
        }
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

    func getDailyNoteID(for dateString: String, completion: @escaping (String) -> Void) {
        let searchText = dateString
        
        let tag = UserDefaults.standard.string(forKey: "dailyNoteTag")?.addingPercentEncodingForRFC3986() ?? ""
        
        let encodedSearchText = searchText.addingPercentEncodingForRFC3986() ?? ""
        let searchURLString = "bear://x-callback-url/search?term=\(searchText)&tag=\(tag)&x-success=fodabear://open-note-success&x-error=fodabear://open-note-error&token=1C9DA6-78D2A9-694BA7"
        if let searchURL = URL(string: searchURLString) {
            print("Searching daily note with URL: \(searchURL)")
            NSWorkspace.shared.open(searchURL)
            DispatchQueue.global().async {
                let result = self.semaphore.wait(timeout: .now() + 10)
                if result == .success {
                    print("Daily note search succeeded")
                    completion(self.noteContent ?? "")
                } else {
                    print("Daily note search timed out")
                    completion("")
                }
            }
        }
    }

    func updateDailyNoteWithCalendarEvents(for dateString: String, noteContent: String, noteId: String) {
            let calendarEventsString = SettingsManager.shared.calendarSectionHeader
            let events = self.fetchCalendarEvents(for: dateString)
            let cleanedEvents = events.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
            
            print("update daily calendar: \(events)")
            let updatedContent = self.replaceCalendarSection(in: noteContent, with: cleanedEvents)
            self.updateNoteContent(newContent: updatedContent, noteID: noteId, open: true, show: true)
    }
    
    func updateHomeNoteWithCalendarEvents(for dateString: String, noteContent: String, homeNoteId: String) {

        let calendarEventsString = SettingsManager.shared.calendarSectionHeader
            let events = self.fetchCalendarEvents(for: dateString)
            let cleanedEvents = events.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
            
            let updatedContent = self.replaceDailySection(in: noteContent, with: dateString)
            let fullyUpdatedContent = self.replaceCalendarSection(in: updatedContent, with: cleanedEvents)
        self.updateNoteContent(newContent: fullyUpdatedContent, noteID: homeNoteId, open: false, show: false)

    }

    func fetchCalendarEvents(for dateString: String) -> String {
        print("Fetching calendar events for date: \(dateString)")
        
        let selectedCalendars = calendarManager.selectedCalendars() // Use selected calendars
        guard !selectedCalendars.isEmpty else {
            print("Warning: No calendars selected")
            return ""
        }
        
        let startDate = getDate(from: dateString)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        
        print("Start date: \(startDate), End date: \(endDate)")
        
        do {
            let predicate = calendarManager.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
            let events = calendarManager.eventStore.events(matching: predicate)
            
            print("Number of events found: \(events.count)")
            
            if events.isEmpty {
                print("No events found for the specified date")
                return "No events scheduled for this day."
            }
            
            let now = Date()
            let formattedEvents = events.map { event in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let startTimeString = formatter.string(from: event.startDate)
                let endTimeString = formatter.string(from: event.endDate)
                
                // Marcar como completada si la fecha de finalización es superior a la hora actual
                let status = event.endDate < now ? "x" : " "
                
                return "- [\(status)] \(startTimeString) - \(endTimeString): \(event.title ?? "")"
            }.joined(separator: "\n")
            
            print("Formatted events:\n\(formattedEvents)")
            
            return formattedEvents
        } catch {
            print("Error fetching calendar events: \(error.localizedDescription)")
            return "Error fetching calendar events"
        }
    }

    func getDailyNoteContent(dailyNoteID: String) -> String {
        // Implementar la lógica para obtener el contenido de la nota diaria usando Bear x-callback-url
        return ""
    }

    func updateDailyNoteContent(newContent: String, dailyNoteID: String) {
        if let encodedContent = newContent.addingPercentEncodingForRFC3986() {
            if let url = URL(string: "bear://x-callback-url/add-text?open_note=no&new_window=no&show_window=no&id=\(dailyNoteID)&mode=replace_all&text=\(encodedContent)") {
                print("Updating daily note with URL: \(url)")
                NSWorkspace.shared.open(url)
            }
        } else {
            print("Failed to encode new content for URL.")
        }
    }
    
    func updateNoteContent(newContent: String, noteID: String, open: Bool, show: Bool) {
        
        let open = open == true ? "yes" : "no"
        let show = show == true ? "yes" : "no"
        
        if let encodedContent = newContent.addingPercentEncodingForRFC3986() {
            if let url = URL(string: "bear://x-callback-url/add-text?open_note=\(open)&show_window=\(show)&id=\(noteID)&mode=replace_all&text=\(encodedContent)") {
                print("Updating note with URL: \(url)")
                NSWorkspace.shared.open(url)
            }
        } else {
            print("Failed to encode new content for URL.")
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

    func createNoteWithContent(_ content: String) {
        if let encodedContent = content.addingPercentEncodingForRFC3986() {
            if let url = URL(string: "bear://x-callback-url/create?text=\(encodedContent)") {
                print("Creating new note with URL: \(url)")
                NSWorkspace.shared.open(url)
            }
        } else {
            print("Failed to encode content for URL.")
        }
    }

    func getDateString(forDaysAfter daysAfter: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: daysAfter, to: Date())!
        return formatter.string(from: date)
    }

    func getDateString(forDaysBefore daysBefore: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: -daysBefore, to: Date())!
        return formatter.string(from: date)
    }

    func getDate(from dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)!
    }
}
