import Foundation
import ServiceManagement
import AppKit

class CalendarSyncManager: ObservableObject {
    static let shared = CalendarSyncManager()
    let noteManager = NoteManager.shared
    var updateTimer: Timer?

    func scheduleCalendarUpdates() {
        // Actualizar la nota diaria y la nota Home cada 10 minutos
//        updateTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
//            self?.updateHomeNoteWithCurrentDateEvents()
//        }

//        // Actualizar notas diarias anteriores hasta 1 semana, cada día
//        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
//            self?.updatePreviousDailyNotes()
//        }
//
//        // Actualizar notas diarias posteriores hasta 1 semana, cada hora
//        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
//            self?.updateNextDailyNotes()
//        }
    }

//    func updatePreviousDailyNotes() {
//        for daysBefore in 1...7 {
//            let previousDateString = getDateString(forDaysBefore: daysBefore)
//            noteManager.getDailyNoteID(for: previousDateString) { [weak self] dailyNoteID in
//                guard let self = self else { return }
//                if !dailyNoteID.isEmpty {
//                    // self.noteManager.updateDailyNoteWithCalendarEvents(for: previousDateString)
//                }
//            }
//        }
//    }
//
//    func updateNextDailyNotes() {
//        for daysAfter in 1...7 {
//            let nextDateString = getDateString(forDaysAfter: daysAfter)
//            noteManager.getDailyNoteID(for: nextDateString) { [weak self] dailyNoteID in
//                guard let self = self else { return }
//                if !dailyNoteID.isEmpty {
//                    // self.noteManager.updateDailyNoteWithCalendarEvents(for: nextDateString)
//                }
//            }
//        }
//    }

    func updateTodayNoteWithCurrentDateEvents() {
//        let dateString = getCurrentDateString()
        // noteManager.updateDailyNoteWithCalendarEvents(for: dateString)
    }

    func updateHomeNoteWithCurrentDateEvents() {
        let dateString = getCurrentDateString()
        let events = noteManager.calendarManager.fetchCalendarEvents(for: dateString)
        noteManager.bearManager.createNoteWithContent(events)
    }

    @objc func syncNow() {
        let calendar = Calendar.current
        let today = Date()
        for i in -7...7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let formattedDate = DateUtils.getCurrentDateFormatted(date: date)
                syncCalendarForDate(formattedDate)
            }
        }
    }
    
    func syncCalendarForDate(_ date: String?) {
        let date = date ?? DateUtils.getCurrentDateFormatted()
       let fetchURLString = "bear://x-callback-url/open-note?title=\(date)&show_window=no&open_note=no&x-success=fodabear://update-daily-note-if-needed-success-for-sync"
       if let fetchURL = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
           print("Fetching daily note with URL: \(fetchURL)")
           NSWorkspace.shared.open(fetchURL)
       }
   }

    private func getDateString(forDaysBefore daysBefore: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: -daysBefore, to: Date())!
        return formatter.string(from: date)
    }

    private func getDateString(forDaysAfter daysAfter: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: daysAfter, to: Date())!
        return formatter.string(from: date)
    }

    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
