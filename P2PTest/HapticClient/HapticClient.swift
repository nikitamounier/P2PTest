struct HapticClient {
  var prepare: @Sendable () async -> Void
  var generateFeedback: @Sendable (FeedbackType) async -> Void
  
  enum FeedbackType: Int {
    case success
    case warning
    case error
  }
}
