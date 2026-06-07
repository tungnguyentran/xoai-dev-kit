//
//  Item.swift
//  XoaiUtility
//
//  Created by Tung Nguyen Tran on 7/6/26.
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
