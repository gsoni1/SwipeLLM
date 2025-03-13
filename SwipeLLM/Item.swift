//
//  Item.swift
//  SwipeLLM
//
//  Created by Gautam Soni on 3/12/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
