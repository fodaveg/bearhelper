//
//  SettingsView.swift
//  BearHelper
//
//  Created by David Velasco on 24/6/24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("homeNoteID") private var homeNoteID: String = ""
    @AppStorage("defaultAction") private var defaultAction: String = "home"
    @AppStorage("dailyNoteTemplate") private var dailyNoteTemplate: String = ""
    @AppStorage("dailyNoteTag") private var dailyNoteTag: String = ""
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    @State private var tempHomeNoteID: String = ""
    @State private var tempDefaultAction: String = "home"
    @State private var tempDailyNoteTemplate: String = ""
    @State private var tempDailyNoteTag: String = ""
    @State private var tempLaunchAtLogin: Bool = false

    var setLaunchAtLogin: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Settings")
                .font(.largeTitle)
                .padding()

            Text("Home Note ID:")
                .padding(.horizontal)
            
            TextField("Paste the note ID here", text: $tempHomeNoteID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Text("Left Click Action:")
                .padding(.horizontal)
            
            Picker("Action", selection: $tempDefaultAction) {
                Text("Disabled").tag("disabled")
                Text("Open Home Note").tag("home")
                Text("Open Daily Note").tag("daily")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Divider()
                .padding(.vertical)
            
            Text("Daily Note Template:")
                .padding(.horizontal)
            
            TextEditor(text: $tempDailyNoteTemplate)
                .border(Color.gray, width: 1)
                .padding(.horizontal)
                .frame(height: 150)
            
            Text("Daily Note Tag:")
                .padding(.horizontal)
            
            TextField("Add tag", text: $tempDailyNoteTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Toggle("Launch at Login", isOn: $tempLaunchAtLogin)
                .padding(.horizontal)
                .onChange(of: tempLaunchAtLogin) { value in
                    setLaunchAtLogin(value)
                }

            HStack {
                Button(action: {
                    // Cancel and discard changes
                    print("Cancel button clicked")
                    closeWindow()
                }) {
                    Text("Cancel")
                }
                .padding()
                
                Spacer()
                
                Button(action: {
                    // Save changes
                    print("Save button clicked")
                    homeNoteID = tempHomeNoteID
                    defaultAction = tempDefaultAction
                    dailyNoteTemplate = tempDailyNoteTemplate
                    dailyNoteTag = tempDailyNoteTag
                    launchAtLogin = tempLaunchAtLogin
                    closeWindow()
                }) {
                    Text("Save")
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 500)
        .onAppear {
            // Load current values
            print("SettingsView appeared")
            tempHomeNoteID = homeNoteID
            tempDefaultAction = defaultAction
            tempDailyNoteTemplate = dailyNoteTemplate
            tempDailyNoteTag = dailyNoteTag
            tempLaunchAtLogin = launchAtLogin
        }
    }

    private func closeWindow() {
        print("Closing settings window")
        NSApp.keyWindow?.close()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(setLaunchAtLogin: { _ in })
    }
}
