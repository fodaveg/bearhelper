//
//  Template.swift
//  BearHelper
//
//  Created by David Velasco on 28/6/24.
//

import Foundation

struct Template: Identifiable, Codable {
    var id = UUID()
    var name: String
    var content: String
    var tag: String
}
