import Foundation
import Darwin

public final class PrivilegeHelper: Sendable {
    public static let shared = PrivilegeHelper()

    public static var helperPath: String? {
        let candidates = [
            Bundle.main.bundlePath + "/amazeRootHelper",
            "/var/jb/Applications/Amaze.app/amazeRootHelper",
            "/Applications/Amaze.app/amazeRootHelper"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func runHelper(action: String, arguments: [String]) throws {
        guard let helper = helperPath else {
            throw NSError(
                domain: "PrivilegeHelper",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "amazeRootHelper not found in application bundle."]
            )
        }

        let fullArgs = [helper, action] + arguments
        var cArgs = fullArgs.map { strdup($0) }
        cArgs.append(nil)
        defer {
            for ptr in cArgs where ptr != nil {
                free(ptr)
            }
        }

        var pid: pid_t = 0
        let spawnErr = posix_spawnp(&pid, helper, nil, nil, &cArgs, environ)
        if spawnErr != 0 {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(spawnErr),
                userInfo: [NSLocalizedDescriptionKey: "posix_spawn failed for \(helper): \(String(cString: strerror(spawnErr)))"]
            )
        }

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let exitCode = (status >> 8) & 0xff
        if exitCode != 0 {
            throw NSError(
                domain: "PrivilegeHelper",
                code: Int(exitCode),
                userInfo: [NSLocalizedDescriptionKey: "Root helper action '\(action)' failed with exit code \(exitCode)"]
            )
        }
    }

    public static func deleteItem(at path: String) throws {
        let cPath = (path as NSString).fileSystemRepresentation
        _ = chmod(cPath, 0o777)

        if (try? FileManager.default.removeItem(atPath: path)) != nil {
            if !FileManager.default.fileExists(atPath: path) {
                return
            }
        }

        var statInfo = stat()
        if lstat(cPath, &statInfo) == 0 {
            if (statInfo.st_mode & S_IFMT) == S_IFDIR {
                if rmdir(cPath) == 0 { return }
            } else {
                if unlink(cPath) == 0 { return }
            }
        }

        if let _ = helperPath {
            try runHelper(action: "delete", arguments: [path])
            if !FileManager.default.fileExists(atPath: path) {
                return
            }
        }

        let rmCandidates = ["/var/jb/usr/bin/rm", "/var/jb/bin/rm", "/bin/rm", "/usr/bin/rm"]
        if let rmBin = rmCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            let args = [rmBin, "-rf", path]
            var cArgs = args.map { strdup($0) }
            cArgs.append(nil)
            defer {
                for ptr in cArgs where ptr != nil { free(ptr) }
            }
            var pid: pid_t = 0
            if posix_spawnp(&pid, rmBin, nil, nil, &cArgs, environ) == 0 {
                var status: Int32 = 0
                waitpid(pid, &status, 0)
                if ((status >> 8) & 0xff) == 0 && !FileManager.default.fileExists(atPath: path) {
                    return
                }
            }
        }

        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(EACCES),
            userInfo: [NSLocalizedDescriptionKey: "Permission denied deleting \(path)."]
        )
    }

    public static func extractArchive(source: String, destination: String) throws {
        let destURL = URL(fileURLWithPath: destination).standardizedFileURL
        _ = chmod((destURL.path as NSString).fileSystemRepresentation, 0o777)

        if let _ = helperPath {
            try runHelper(action: "extract", arguments: [source, destURL.path])
            return
        }

        throw NSError(
            domain: "PrivilegeHelper",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Root helper required for privileged extraction."]
        )
    }

    public static func setPermissions(_ mode: mode_t, at path: String) throws {
        let rc = chmod((path as NSString).fileSystemRepresentation, mode)
        if rc == 0 { return }

        if let _ = helperPath {
            let octal = String(mode, radix: 8)
            try runHelper(action: "chmod", arguments: [octal, path])
            return
        }

        let err = errno
        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(err),
            userInfo: [NSLocalizedDescriptionKey: "chmod failed: \(String(cString: strerror(err)))"]
        )
    }

    public static func createDirectory(at path: String) throws {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return
        } catch {
            if let _ = helperPath {
                try runHelper(action: "mkdir", arguments: [path])
                return
            }
            throw error
        }
    }
}
