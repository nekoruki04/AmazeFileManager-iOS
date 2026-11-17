// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import Darwin

public protocol FileOperationDelegate: AnyObject, Sendable {
    func operationDidUpdateProgress(_ progress: OperationProgress)
    func operationDidComplete(id: UUID, type: OperationType)
    func operationDidFail(id: UUID, type: OperationType, error: String)
}

public actor FileOperationsQueue {
    public static let shared = FileOperationsQueue()

    private var activeTasks: [UUID: Task<Void, Error>] = [:]
    private nonisolated(unsafe) var delegates: [UUID: @Sendable (OperationProgress) -> Void] = [:]

    private init() {}

    public func registerProgressHandler(for id: UUID, handler: @escaping @Sendable (OperationProgress) -> Void) {
        delegates[id] = handler
    }

    public func cancelOperation(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        delegates.removeValue(forKey: id)
    }

    /// Performs safe asynchronous copy of files or directories with chunked streaming.
    public func copy(
        sources: [String],
        destinationDirectory: String,
        conflictPolicy: ConflictResolution = .keepBoth
    ) async throws -> UUID {
        let opId = UUID()
        let task = Task.detached(priority: .userInitiated) {
            var totalBytes: Int64 = 0
            for src in sources {
                totalBytes += self.calculateTotalSize(at: src)
            }

            var bytesCompleted: Int64 = 0
            for src in sources {
                try Task.checkCancellation()
                let filename = (src as NSString).lastPathComponent
                var target = (destinationDirectory as NSString).appendingPathComponent(filename)

                if FileManager.default.fileExists(atPath: target) {
                    switch conflictPolicy {
                    case .skip:
                        continue
                    case .overwrite:
                        try? FileManager.default.removeItem(atPath: target)
                    case .keepBoth:
                        target = ConflictResolver.nonConflictingPath(for: target)
                    }
                }

                try self.copyRecursive(
                    source: src,
                    destination: target,
                    opId: opId,
                    totalBytes: totalBytes,
                    bytesCompleted: &bytesCompleted
                )
            }
        }

        activeTasks[opId] = task
        try await task.value
        activeTasks.removeValue(forKey: opId)
        delegates.removeValue(forKey: opId)
        return opId
    }

    /// Performs move operation. Uses atomic rename if possible; falls back to copy + delete.
    public func move(
        sources: [String],
        destinationDirectory: String,
        conflictPolicy: ConflictResolution = .keepBoth
    ) async throws -> UUID {
        let opId = UUID()
        let task = Task.detached(priority: .userInitiated) {
            var totalBytes: Int64 = 0
            for src in sources {
                totalBytes += self.calculateTotalSize(at: src)
            }

            var bytesCompleted: Int64 = 0
            for src in sources {
                try Task.checkCancellation()
                let filename = (src as NSString).lastPathComponent
                var target = (destinationDirectory as NSString).appendingPathComponent(filename)

                if FileManager.default.fileExists(atPath: target) {
                    switch conflictPolicy {
                    case .skip:
                        continue
                    case .overwrite:
                        try? FileManager.default.removeItem(atPath: target)
                    case .keepBoth:
                        target = ConflictResolver.nonConflictingPath(for: target)
                    }
                }

                let srcC = (src as NSString).fileSystemRepresentation
                let dstC = (target as NSString).fileSystemRepresentation

                // Attempt atomic rename first
                if rename(srcC, dstC) == 0 {
                    bytesCompleted += self.calculateTotalSize(at: target)
                    self.reportProgress(opId: opId, type: .move, currentItem: filename, completed: bytesCompleted, total: totalBytes)
                    continue
                }

                // If cross-device link (EXDEV), copy and then delete source
                try self.copyRecursive(
                    source: src,
                    destination: target,
                    opId: opId,
                    totalBytes: totalBytes,
                    bytesCompleted: &bytesCompleted
                )
                try self.deleteInternal(path: src)
            }
        }

        activeTasks[opId] = task
        try await task.value
        activeTasks.removeValue(forKey: opId)
        delegates.removeValue(forKey: opId)
        return opId
    }

    /// Deletes files or directories safely with root filesystem path guards.
    public func delete(paths: [String]) async throws -> UUID {
        let opId = UUID()
        let task = Task.detached(priority: .userInitiated) {
            let total = Int64(paths.count)
            var count: Int64 = 0
            for path in paths {
                try Task.checkCancellation()
                // Critical security check: guard protected root paths
                guard self.isSafeToDelete(path: path) else {
                    throw NSError(
                        domain: "FileOperationsQueue",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Protected system path cannot be deleted: \(path)"]
                    )
                }
                try self.deleteInternal(path: path)
                count += 1
                self.reportProgress(opId: opId, type: .delete, currentItem: (path as NSString).lastPathComponent, completed: count, total: total)
            }
        }

        activeTasks[opId] = task
        try await task.value
        activeTasks.removeValue(forKey: opId)
        delegates.removeValue(forKey: opId)
        return opId
    }

    /// Renames a single file or directory.
    public func renameItem(at path: String, to newName: String) throws {
        let parent = (path as NSString).deletingLastPathComponent
        let target = (parent as NSString).appendingPathComponent(newName)
        if FileManager.default.fileExists(atPath: target) {
            throw NSError(domain: "FileOperationsQueue", code: 409, userInfo: [NSLocalizedDescriptionKey: "An item named '\(newName)' already exists."])
        }
        let rc = rename((path as NSString).fileSystemRepresentation, (target as NSString).fileSystemRepresentation)
        if rc != 0 {
            let err = errno
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Rename failed: \(String(cString: strerror(err)))"])
        }
    }

    // MARK: - Private Helpers

    private nonisolated func isSafeToDelete(path: String) -> Bool {
        let clean = (path as NSString).standardizingPath
        let forbidden: Set<String> = [
            "/", "/var", "/var/mobile", "/var/jb", "/private", "/System", "/Library",
            "/Applications", "/usr", "/bin", "/sbin", "/etc", "/dev", "/Volumes"
        ]
        if forbidden.contains(clean) { return false }
        return true
    }

    private nonisolated func deleteInternal(path: String) throws {
        try PrivilegeHelper.deleteItem(at: path)
    }

    private nonisolated func calculateTotalSize(at path: String) -> Int64 {
        var statInfo = stat()
        guard lstat((path as NSString).fileSystemRepresentation, &statInfo) == 0 else { return 0 }
        if (statInfo.st_mode & S_IFMT) != S_IFDIR {
            return Int64(statInfo.st_size)
        }
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let full = (path as NSString).appendingPathComponent(file)
                if lstat((full as NSString).fileSystemRepresentation, &statInfo) == 0 {
                    if (statInfo.st_mode & S_IFMT) != S_IFDIR {
                        total += Int64(statInfo.st_size)
                    }
                }
            }
        }
        return total
    }

    private nonisolated func copyRecursive(
        source: String,
        destination: String,
        opId: UUID,
        totalBytes: Int64,
        bytesCompleted: inout Int64
    ) throws {
        var statInfo = stat()
        guard lstat((source as NSString).fileSystemRepresentation, &statInfo) == 0 else { return }

        if (statInfo.st_mode & S_IFMT) == S_IFDIR {
            try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
            chmod((destination as NSString).fileSystemRepresentation, statInfo.st_mode)

            guard let dir = opendir((source as NSString).fileSystemRepresentation) else { return }
            defer { closedir(dir) }

            while let entry = readdir(dir) {
                let name = withUnsafeBytes(of: entry.pointee.d_name) { rawPtr -> String in
                    guard let base = rawPtr.baseAddress else { return "" }
                    return String(cString: base.assumingMemoryBound(to: CChar.self))
                }
                if name == "." || name == ".." { continue }

                let subSrc = (source as NSString).appendingPathComponent(name)
                let subDst = (destination as NSString).appendingPathComponent(name)
                try copyRecursive(source: subSrc, destination: subDst, opId: opId, totalBytes: totalBytes, bytesCompleted: &bytesCompleted)
            }
        } else if (statInfo.st_mode & S_IFMT) == S_IFLNK {
            var buffer = [CChar](repeating: 0, count: 1024)
            let len = readlink((source as NSString).fileSystemRepresentation, &buffer, 1023)
            if len > 0 {
                buffer[len] = 0
                symlink(buffer, (destination as NSString).fileSystemRepresentation)
            }
        } else {
            // Regular file copy using 64 KB streaming buffer
            guard let inStream = InputStream(fileAtPath: source),
                  let outStream = OutputStream(toFileAtPath: destination, append: false) else {
                throw NSError(domain: "FileOperationsQueue", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open stream for \(source) -> \(destination)"])
            }

            inStream.open()
            outStream.open()
            defer {
                inStream.close()
                outStream.close()
            }

            let bufferSize = 65536
            var buffer = [UInt8](repeating: 0, count: bufferSize)

            while inStream.hasBytesAvailable {
                try Task.checkCancellation()
                let read = inStream.read(&buffer, maxLength: bufferSize)
                if read < 0 {
                    throw inStream.streamError ?? NSError(domain: "FileOperationsQueue", code: 3, userInfo: nil)
                }
                if read == 0 { break }

                var written = 0
                while written < read {
                    let writeCount = outStream.write(&buffer[written], maxLength: read - written)
                    if writeCount <= 0 {
                        throw outStream.streamError ?? NSError(domain: "FileOperationsQueue", code: 4, userInfo: nil)
                    }
                    written += writeCount
                }

                bytesCompleted += Int64(read)
                reportProgress(
                    opId: opId,
                    type: .copy,
                    currentItem: (source as NSString).lastPathComponent,
                    completed: bytesCompleted,
                    total: totalBytes
                )
            }

            chmod((destination as NSString).fileSystemRepresentation, statInfo.st_mode)
        }
    }

    private nonisolated func reportProgress(
        opId: UUID,
        type: OperationType,
        currentItem: String,
        completed: Int64,
        total: Int64
    ) {
        let prog = OperationProgress(
            operationId: opId,
            type: type,
            currentItem: currentItem,
            bytesCompleted: completed,
            totalBytes: total
        )
        delegates[opId]?(prog)
    }
}
