// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation

public enum NetworkProtocolType: String, CaseIterable, Codable, Sendable {
    case ftp = "FTP"
    case ftps = "FTPS"
    case sftp = "SFTP"
    case smb = "SMB2/SMB3 (Unsupported)"

    public var isSupported: Bool {
        switch self {
        case .ftp, .ftps, .sftp: return true
        case .smb: return false
        }
    }
}

public struct NetworkServerConfig: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var protocolType: NetworkProtocolType
    public var host: String
    public var port: Int
    public var username: String
    public var remoteBasePath: String

    public init(
        id: UUID = UUID(),
        name: String,
        protocolType: NetworkProtocolType,
        host: String,
        port: Int? = nil,
        username: String,
        remoteBasePath: String = "/"
    ) {
        self.id = id
        self.name = name
        self.protocolType = protocolType
        self.host = host
        self.username = username
        self.remoteBasePath = remoteBasePath

        if let p = port {
            self.port = p
        } else {
            switch protocolType {
            case .ftp: self.port = 21
            case .ftps: self.port = 990
            case .sftp: self.port = 22
            case .smb: self.port = 445
            }
        }
    }

    public var keychainAccountKey: String {
        return "\(protocolType.rawValue)_\(host)_\(port)_\(username)"
    }
}

public struct RemoteFileItem: Identifiable, Sendable {
    public var id: String { remotePath }
    public let name: String
    public let remotePath: String
    public let isDirectory: Bool
    public let size: Int64
    public let modificationDate: Date?
}
