struct ProximitySensorClient {
  var sensedProximity: @Sendable () async -> Bool
}
