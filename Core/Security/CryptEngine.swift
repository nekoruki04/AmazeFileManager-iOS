// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import CryptoKit
import CommonCrypto

public struct CryptEngine: Sendable {
    private static let saltSize = 16
    private static let keyIterations: UInt32 = 100_000

    /// Derives a 256-bit symmetric key from password and salt using PBKDF2 with SHA-256.
    public static func deriveKey(password: String, salt: Data) -> SymmetricKey? {
        guard let passwordData = password.data(using: .utf8) else { return nil }
        var derivedKey = Data(repeating: 0, count: 32)

        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        keyIterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return SymmetricKey(data: derivedKey)
    }

    /// Encrypts source file into destination file using AES-GCM with PBKDF2 derived key.
    public static func encryptFile(at sourcePath: String, to destinationPath: String, password: String) throws {
        let plaintextData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))

        // Generate random 16-byte salt
        var salt = Data(count: saltSize)
        let saltResult = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltSize, $0.baseAddress!) }
        guard saltResult == errSecSuccess, let key = deriveKey(password: password, salt: salt) else {
            throw NSError(domain: "CryptEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key derivation failed."])
        }

        let sealedBox = try AES.GCM.seal(plaintextData, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "CryptEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Encryption failed."])
        }

        // Output format: [16 bytes Salt] + [Combined AES-GCM payload (Nonce + Ciphertext + Tag)]
        var payload = Data()
        payload.append(salt)
        payload.append(combined)

        try payload.write(to: URL(fileURLWithPath: destinationPath), options: .atomic)
    }

    /// Decrypts encrypted file using password.
    public static func decryptFile(at sourcePath: String, to destinationPath: String, password: String) throws {
        let payload = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
        guard payload.count > saltSize + 28 else { // Salt (16) + Nonce (12) + Tag (16)
            throw NSError(domain: "CryptEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "File is not a valid encrypted payload."])
        }

        let salt = payload.subdata(in: 0..<saltSize)
        let encryptedData = payload.subdata(in: saltSize..<payload.count)

        guard let key = deriveKey(password: password, salt: salt) else {
            throw NSError(domain: "CryptEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Key derivation failed."])
        }

        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        try decryptedData.write(to: URL(fileURLWithPath: destinationPath), options: .atomic)
    }
}
