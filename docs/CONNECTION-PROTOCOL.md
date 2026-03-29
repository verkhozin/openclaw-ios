# Connection Protocol -- полный рабочий рецепт

Проверено 2026-03-29. Все шаги протестированы до рабочего подключения с operator.write scope.

## Что мы выяснили (хронология ошибок)

1. **type: "connect"** -- НЕПРАВИЛЬНО. Должен быть `type: "req"`, `method: "connect"`
2. **client.id: "clios"** -- НЕПРАВИЛЬНО. Gateway валидирует по enum. Допустимые: `cli`, `webchat`, `webchat-ui`, `openclaw-control-ui`, `gateway-client`, `openclaw-macos`, `openclaw-ios`, `openclaw-android`, `node-host`, `test`, `fingerprint`, `openclaw-probe`
3. **client.mode: "operator"** -- НЕПРАВИЛЬНО. Допустимые: `node`, `cli`, `ui`, `webchat`, `test`, `backend`, `probe`
4. **Без device блока** -- подключение проходит, но scopes = none (только read). Для operator.write ОБЯЗАТЕЛЕН device с ed25519 подписью.
5. **Отправка connect frame до challenge** -- Gateway шлет connect.challenge первым. СНАЧАЛА ждем challenge, ПОТОМ отправляем connect.
6. **@MainActor async задержка** -- challenge handler должен отвечать быстро, без лишних async переключений
7. **deviceId = SHA256(rawKey).hex().substring(0,32)** -- НЕПРАВИЛЬНО. Полный hex без truncation.
8. **deviceFamily в v3 payload** -- пустая строка если не указан

## Рабочий flow

### 1. Генерация keypair (один раз, сохранить в Keychain)

```
Algorithm: Ed25519
Store: privateKey + publicKey PEM в Keychain
deviceId: SHA256(raw 32-byte public key).hex() -- полный 64-char hex
```

iOS: `Curve25519.Signing.PrivateKey()` из CryptoKit

### 2. Открыть WebSocket

```
URL: ws://{host}:{port}  (НЕ wss:// -- нет TLS)
Default port: 18789
```

### 3. Получить challenge

Gateway шлет первым:
```json
{
  "type": "event",
  "event": "connect.challenge",
  "payload": { "nonce": "uuid-string", "ts": 1774800000000 }
}
```

### 4. Подписать и отправить connect frame

Payload для подписи (v3 формат, pipe-separated):
```
v3|{deviceId}|openclaw-ios|ui|operator|operator.read,operator.write,operator.approvals,operator.pairing|{signedAtMs}|{token}|{nonce}|ios|
```

Последнее поле (deviceFamily) -- пустая строка.

Подпись: `base64url(ed25519_sign(payload_string, privateKey))`
Public key для отправки: `base64url(raw 32-byte public key)`

Connect frame:
```json
{
  "type": "req",
  "id": "<uuid>",
  "method": "connect",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "openclaw-ios",
      "version": "1.0.0",
      "platform": "ios",
      "mode": "ui"
    },
    "role": "operator",
    "scopes": ["operator.read", "operator.write", "operator.approvals", "operator.pairing"],
    "caps": [],
    "commands": [],
    "permissions": {},
    "auth": { "token": "<gateway token>" },
    "device": {
      "id": "<deviceId - SHA256 hex 64 chars>",
      "publicKey": "<base64url raw 32 bytes>",
      "signature": "<base64url ed25519 signature>",
      "signedAt": <milliseconds timestamp>,
      "nonce": "<nonce from challenge>"
    },
    "locale": "en-US",
    "userAgent": "CLiOS/1.0.0"
  }
}
```

### 5. Получить hello-ok

```json
{
  "type": "res",
  "id": "<same as request>",
  "ok": true,
  "payload": {
    "type": "hello-ok",
    "protocol": 3,
    "server": { "version": "2026.3.13", "connId": "..." },
    "auth": {
      "deviceToken": "<save this for reconnects>",
      "role": "operator",
      "scopes": ["operator.approvals", "operator.pairing", "operator.read", "operator.write"]
    },
    "snapshot": { ... },
    "policy": { "tickIntervalMs": 30000, ... }
  }
}
```

Сохранить `deviceToken` в Keychain -- можно использовать для быстрых reconnects.

### 6. Отправка сообщений

chat.send ТРЕБУЕТ idempotencyKey:
```json
{
  "type": "req",
  "id": "<uuid>",
  "method": "chat.send",
  "params": {
    "message": "Hello!",
    "sessionKey": "agent:scout:main",
    "idempotencyKey": "<uuid>"
  }
}
```

## Gateway config (на сервере)

Для доступа извне нужно:
```json
{
  "gateway": {
    "bind": "0.0.0.0",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "<gateway token>"
    }
  }
}
```

## Node.js тест-скрипт (рабочий, проверенный)

```javascript
const WebSocket = require('ws');
const crypto = require('crypto');

const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");
const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
const spki = publicKey.export({ type: 'spki', format: 'der' });
const rawKey = spki.subarray(ED25519_SPKI_PREFIX.length);
const deviceId = crypto.createHash('sha256').update(rawKey).digest('hex');

function base64UrlEncode(buf) {
  return Buffer.from(buf).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const TOKEN = '<gateway token>';
const ws = new WebSocket('ws://<host>:18789');

ws.on('message', (data) => {
  const frame = JSON.parse(data.toString());
  
  if (frame.type === 'event' && frame.event === 'connect.challenge') {
    const nonce = frame.payload.nonce;
    const signedAtMs = Date.now();
    const scopes = ["operator.read","operator.write","operator.approvals","operator.pairing"];
    
    const payload = [
      'v3', deviceId, 'openclaw-ios', 'ui', 'operator',
      scopes.join(','), String(signedAtMs), TOKEN, nonce, 'ios', ''
    ].join('|');
    
    const signature = base64UrlEncode(
      crypto.sign(null, Buffer.from(payload, 'utf8'), privateKey)
    );
    
    ws.send(JSON.stringify({
      type: "req", id: "c1", method: "connect",
      params: {
        minProtocol: 3, maxProtocol: 3,
        client: { id: "openclaw-ios", version: "1.0.0", platform: "ios", mode: "ui" },
        role: "operator", scopes,
        caps: [], commands: [], permissions: {},
        auth: { token: TOKEN },
        device: {
          id: deviceId,
          publicKey: base64UrlEncode(rawKey),
          signature, signedAt: signedAtMs, nonce
        },
        locale: "en-US", userAgent: "CLiOS/1.0.0"
      }
    }));
  }
  
  if (frame.type === 'res' && frame.ok) {
    console.log('CONNECTED!', JSON.stringify(frame.payload.auth));
  }
});
```

## iOS CryptoKit эквивалент

```swift
import CryptoKit
import Foundation

// Generate keypair (once, store in Keychain)
let privateKey = Curve25519.Signing.PrivateKey()
let publicKey = privateKey.publicKey
let rawKeyData = publicKey.rawRepresentation  // 32 bytes

// Device ID
let deviceId = SHA256.hash(data: rawKeyData)
    .map { String(format: "%02x", $0) }.joined()  // 64-char hex

// Base64URL encode
func base64url(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

// Sign challenge
func signChallenge(nonce: String, token: String, signedAtMs: Int64) -> (signature: String, signedAt: Int64) {
    let scopes = "operator.read,operator.write,operator.approvals,operator.pairing"
    let payload = "v3|\(deviceId)|openclaw-ios|ui|operator|\(scopes)|\(signedAtMs)|\(token)|\(nonce)|ios|"
    let payloadData = Data(payload.utf8)
    let signature = try! privateKey.signature(for: payloadData)
    return (base64url(signature.rawRepresentation), signedAtMs)
}
```
