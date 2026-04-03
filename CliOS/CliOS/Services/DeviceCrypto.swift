import Foundation
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "DeviceCrypto")

/// Ed25519 device identity for OpenClaw gateway handshake.
/// Generates keypair once, stores in Keychain, provides signing.
enum DeviceCrypto {

    // MARK: - Public API

    /// Device ID = SHA256(raw public key bytes).hex
    static var deviceId: String {
        let key = loadOrCreateKey()
        let hash = SHA256.hash(data: key.publicKey.rawRepresentation)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Public key as base64url (raw 32 bytes)
    static var publicKeyBase64URL: String {
        let key = loadOrCreateKey()
        return base64url(key.publicKey.rawRepresentation)
    }

    /// Sign the v3 challenge payload and return base64url signature.
    static func signChallenge(
        nonce: String,
        token: String,
        signedAtMs: Int64
    ) -> String {
        let key = loadOrCreateKey()
        let devId = deviceId

        // v3|{deviceId}|openclaw-ios|ui|operator|scopes|{signedAtMs}|{token}|{nonce}|ios|
        let scopes = "operator.read,operator.write,operator.approvals,operator.pairing"
        let payload = "v3|\(devId)|openclaw-ios|ui|operator|\(scopes)|\(signedAtMs)|\(token)|\(nonce)|ios|"

        logger.debug("Signing payload (\(payload.count) chars)")

        let payloadData = Data(payload.utf8)
        let signature = try! key.signature(for: payloadData)
        return base64url(signature)
    }

    // MARK: - Key management

    private static let keychainKey = "deviceSigningKey"

    /// Cached in-memory to avoid repeated Keychain reads per launch
    private static var _cachedKey: Curve25519.Signing.PrivateKey?

    private static func loadOrCreateKey() -> Curve25519.Signing.PrivateKey {
        // Return cached key if we already loaded this session
        if let cached = _cachedKey { return cached }

        // Try to load from Keychain
        if let raw = KeychainService.load(key: keychainKey),
           let data = Data(base64Encoded: raw),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            logger.info("Loaded existing keypair from Keychain (deviceId prefix: \(deviceIdPrefix(key)))")
            _cachedKey = key
            return key
        }

        // Generate new keypair and persist
        logger.info("No keypair in Keychain — generating new ed25519 keypair")
        let key = Curve25519.Signing.PrivateKey()
        let raw = key.rawRepresentation.base64EncodedString()
        let saved = KeychainService.save(key: keychainKey, value: raw)
        if saved {
            logger.info("Keypair saved to Keychain (deviceId prefix: \(deviceIdPrefix(key)))")
        } else {
            logger.error("FAILED to save keypair to Keychain — key will be regenerated next launch!")
        }
        _cachedKey = key
        return key
    }

    private static func deviceIdPrefix(_ key: Curve25519.Signing.PrivateKey) -> String {
        let hash = SHA256.hash(data: key.publicKey.rawRepresentation)
        return hash.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - base64url encoding

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64url<S: ContiguousBytes>(_ signature: S) -> String {
        let data: Data
        if let sig = signature as? Data {
            data = sig
        } else {
            data = signature.withUnsafeBytes { Data($0) }
        }
        return base64url(data)
    }
}
