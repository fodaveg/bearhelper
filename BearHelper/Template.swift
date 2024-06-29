//
//  Template.swift
//  BearHelper
//
//  Created by David Velasco on 28/6/24.
//

import Foundation

struct Template: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var content: String
    var tag: String
    var isDaily: Bool

    init(id: UUID = UUID(), name: String, content: String, tag: String, isDaily: Bool = false) {
        self.id = id
        self.name = name
        self.content = content
        self.tag = tag
        self.isDaily = isDaily
    }
}
