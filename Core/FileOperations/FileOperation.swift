// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation

public enum OperationType: String, Sendable {
    case copy = "Copy"
    case move = "Move"
    case delete = "Delete"
    case rename = "Rename"
    case duplicate = "Duplicate"
    case chmod = "Change Permissions"
    case compress = "Compress"
    case extract = "Extract"
}

public enum OperationStatus: Sendable {
    case pending
    case inProgress(fractionCompleted: Double, currentItem: String)
    case completed
    case failed(error: String)
    case cancelled
}

public enum ConflictResolution: Sendable {
    case overwrite
    case skip
    case keepBoth
}

public struct OperationProgress: Sendable {
    public let operationId: UUID
    public let type: OperationType
    public let currentItem: String
    public let bytesCompleted: Int64
    public let totalBytes: Int64
    public let fractionCompleted: Double
    public let isIndeterminate: Bool

    public init(
        operationId: UUID,
        type: OperationType,
        currentItem: String,
        bytesCompleted: Int64,
        totalBytes: Int64,
        isIndeterminate: Bool = false
    ) {
        self.operationId = operationId
        self.type = type
        self.currentItem = currentItem
        self.bytesCompleted = bytesCompleted
        self.totalBytes = totalBytes
        self.isIndeterminate = isIndeterminate
        if totalBytes > 0 {
            self.fractionCompleted = min(1.0, max(0.0, Double(bytesCompleted) / Double(totalBytes)))
        } else {
            self.fractionCompleted = 0.0
        }
    }
}
