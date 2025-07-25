//
//  Item.swift
//  SentimentAnalysisApp
//
//  Created by Logan Houp on 7/10/25.
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
