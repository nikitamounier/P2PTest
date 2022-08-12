import UIKit

extension HapticClient {
  static var live: Self {
    let haptic = Haptic()
    return Self(
      prepare: { await haptic.prepare() },
      generateFeedback: { await haptic.generateFeedback(for: $0) }
    )
  }
}

private final class Haptic {
  var feedbackGenerator: UINotificationFeedbackGenerator?
  
  @MainActor
  func prepare() {
    self.feedbackGenerator = UINotificationFeedbackGenerator()
    self.feedbackGenerator?.prepare()
  }
  
  @MainActor
  func generateFeedback(for feedbackType: HapticClient.FeedbackType) {
    self.feedbackGenerator?.notificationOccurred(.init(rawValue: feedbackType.rawValue)!)
  }
}
