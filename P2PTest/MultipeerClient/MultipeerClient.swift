import MultipeerKit

struct MultipeerClient {
    var start: @Sendable (_ peerID: String) async -> AsyncStream<PeerID>
    var send: @Sendable (UserProfile, _ to: PeerID) async throws -> ()
    var receive: @Sendable (_ from: PeerID) async -> UserProfile
}

struct PeerID: Equatable {
    let name: String
}
