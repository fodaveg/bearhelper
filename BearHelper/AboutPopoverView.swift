//
//  AboutPopoverView.swift
//  BearHelper
//
//  Created by David Velasco on 28/6/24.
//

import SwiftUI

struct AboutPopoverView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Bear Claw")
                .font(.title)
            Text("Version 0.1")
                .font(.subheadline)
            Spacer()
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.blue)
                Text("Email:")
                Link("fodaveg@fodaveg.net", destination: URL(string: "mailto:fodaveg@fodaveg.net")!)
            }
            .padding(.vertical, 5)
            HStack {
                if let mastodonIcon = NSImage(named: "mastodon") {
                    Image(nsImage: mastodonIcon)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text("Mastodon:")
                Link("@fodaveg", destination: URL(string: "https://masto.es/@fodaveg")!)
            }
            
            .padding(.vertical, 5)
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
