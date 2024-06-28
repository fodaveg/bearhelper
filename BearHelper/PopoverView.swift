//
//  PopoverView.swift
//  BearHelper
//
//  Created by David Velasco on 24/6/24.
//

import SwiftUI

struct PopoverView: View {
    @AppStorage("homeNoteID") private var homeNoteID: String = ""
    @AppStorage("dailyNoteTemplate") private var dailyNoteTemplate: String = ""
    @AppStorage("dailyNoteTag") private var dailyNoteTag: String = ""

    var body: some View {
        VStack {
            Button("Open Home Note") {
                openHomeNote()
            }
            Button("Generate Daily Note") {
                generateDailyNote()
            }
            Divider()
            Button("Settings") {
                openSettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
    }

    private func openHomeNote() {
        guard let url = URL(string: "bear://x-callback-url/open-note?id=\(homeNoteID)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func generateDailyNote() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        let title = "Daily Note \(dateString)"
        var urlString = "bear://x-callback-url/create?title=\(title)&text=\(dailyNoteTemplate)"
        if !dailyNoteTag.isEmpty {
            urlString += "&tags=\(dailyNoteTag)"
        }
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openSettings() {
        // Implement open settings logic
    }
}
