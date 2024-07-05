//
//  DailyNoteManager.swift
//  BearHelper
//
//  Created by David Velasco on 2/7/24.
//

//import Foundation
//
//class DailyNoteManager {
//    static let shared = DailyNoteManager()
//
//    @objc func openDailyNote() {
//        let dateToday = getCurrentDateFormatted()
//        let dailiesTag = SettingsManager.shared.loadTemplates().first(where: { $0.name == "Daily" })?.tag ?? ""
//        let homeNoteId = SettingsManager.shared.homeNoteID
//
//        let url = "bear://x-callback-url/open-note?title=\(dateToday)&open_note=yes&show_window=yes&exclude_trashed=yes"
//        
//        // NoteManager.shared.replaceDateOnHome(homeNoteId)
//        //NoteManager.shared.updateHomeNoteIfNeeded(homeNoteID: homeNoteId, todayDateString: dateToday)
//        print("dateToday: \(dateToday)")
//        //  NoteManager.shared.updateCalendarEventsOnNote(dailyID)
//        
//        BearAPIManager.shared.openDailyNoteDirect(title: dateToday)
//    
//    }
//
//    func createDailyNoteWithDate(_ date: String?) {
//        let date = date ?? getCurrentDateFormatted()
//        guard let template = SettingsManager.shared.loadTemplates().first(where: { $0.name == "Daily" }) else { return }
//        
//        let processedContent = NoteManager.shared.processTemplateVariables(template.content,for: date)
//        let tag = template.tag
//
//        BearAPIManager.shared.createNoteDirect(title: nil, content: processedContent, tags: [tag], open: true)
//    }
//
//    func getCurrentDateFormatted() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd"
//        return formatter.string(from: Date())
//    }
//}
