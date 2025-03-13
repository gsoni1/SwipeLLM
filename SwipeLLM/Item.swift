//
//  Item.swift
//  SwipeLLM
//
//  Created by Gautam Soni on 3/12/25.
//

import Foundation
import SwiftData

@Model
final class WebPage {
    var url: String
    var title: String
    var timestamp: Date
    var order: Int
    
    init(url: String, title: String, timestamp: Date = Date(), order: Int = 0) {
        self.url = url
        self.title = title
        self.timestamp = timestamp
        self.order = order
    }
}
