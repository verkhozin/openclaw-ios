import Foundation

/// Parsed agent event from WebSocket frame.
/// Raw JSON: { "type":"event", "event":"agent", "payload": { "runId", "stream", "data", ... } }
struct AgentEvent {
    let runId: String
    let stream: Stream
    let sessionKey: String
    let seq: Int

    enum Stream {
        case lifecycleStart
        case lifecycleEnd
        case assistant(text: String, delta: String)
    }

    /// Try to parse an agent event from a raw JSON dictionary.
    /// Returns nil if this isn't an agent event.
    static func from(_ json: [String: Any]) -> AgentEvent? {
        guard let type = json["type"] as? String, type == "event",
              let event = json["event"] as? String, event == "agent",
              let payload = json["payload"] as? [String: Any],
              let runId = payload["runId"] as? String,
              let streamStr = payload["stream"] as? String,
              let data = payload["data"] as? [String: Any] else {
            return nil
        }

        let sessionKey = payload["sessionKey"] as? String ?? ""
        let seq = payload["seq"] as? Int ?? 0

        let stream: Stream
        switch streamStr {
        case "lifecycle":
            let phase = data["phase"] as? String ?? ""
            switch phase {
            case "start": stream = .lifecycleStart
            case "end": stream = .lifecycleEnd
            default: return nil
            }
        case "assistant":
            let text = data["text"] as? String ?? ""
            let delta = data["delta"] as? String ?? ""
            stream = .assistant(text: text, delta: delta)
        default:
            return nil
        }

        return AgentEvent(runId: runId, stream: stream, sessionKey: sessionKey, seq: seq)
    }
}
