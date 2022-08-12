import ComposableArchitecture
import MultipeerKit
import SwiftUI

struct P2PState: Equatable {
  var beacons: [Beacon] = []
  var peers: [PeerID] = []
  var userProfile = UserProfile(name: "Nikita Mounier")
  var peerProfile: UserProfile? = nil
  
  @BindableState var shareButtonPressed: Bool = false
  @BindableState var isBeaconTwo: Bool = false
}

enum P2PAction: Equatable, BindableAction {
  case task
  case beaconsResponse([Beacon])
  case peerResponse(PeerID)
  case receivedProfileResponse(UserProfile)
  case shareButtonPressed
  case confirmationPressed
  case binding(BindingAction<P2PState>)
  
}

struct P2PEnvironment {
  var beacon: BeaconClient
  var multipeer: MultipeerClient
  var orientation: OrientationClient
  var proximitySensor: ProximitySensorClient
}

let p2pReducer = Reducer<P2PState, P2PAction, P2PEnvironment> { state, action, environment in
  
  switch action {
  case .task:
    return .run { [shareButtonPressed = state.shareButtonPressed, isBeaconTwo = state.isBeaconTwo] send in
      
      let major: UInt16 = isBeaconTwo ? 0 : 1
      let minor: UInt16 = isBeaconTwo ? 0 : 1
      
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          for try await beacons in await environment.beacon.start(major, minor) {
            await send(.beaconsResponse(beacons))
          }
        }
        
        group.addTask {
          let myPeerID = "\(String(format: "%016d-%016d", major, minor))"
          for await peer in await environment.multipeer.start(myPeerID) {
            await send(.peerResponse(peer))
          }
        }
      }
      
    } catch: { error, send in
      print("p2p/beacon error", error.localizedDescription)
    }
    
  case let .beaconsResponse(beacons):
    state.beacons = beacons
    return .none
    
  case let .peerResponse(peer):
    state.peers.append(peer)
    return .none
    
    
  case .shareButtonPressed:
    state.shareButtonPressed = true
    
    return .task { [profile = state.userProfile, peers = state.peers, beacons = state.beacons] in
      async let isHorizontal = environment.orientation.horizontal()
      async let sensedProximity = environment.proximitySensor.sensedProximity()
      
      _ = await (isHorizontal, sensedProximity)
      
      
      let closestBeacon = beacons
        .filter { $0.proximity == .immediate || $0.proximity == .near }
        .max { $0.accuracy < $1.accuracy && $0.rssi > $1.rssi }!
      
      let closestPeer = peers.first {
        $0.name == "\(String(format: "%016d-%016d", closestBeacon.major, closestBeacon.minor))"
      }!
      
      async let sending: Void = environment.multipeer.send(profile, closestPeer)
      async let receivedProfile: UserProfile = environment.multipeer.receive(closestPeer)
      
      let (_, profile) = try await (sending, receivedProfile)
      
      return .receivedProfileResponse(profile)
      
    } catch: { error in
      
      print("send/receive error", error.localizedDescription)
      return .binding(.set(\.$shareButtonPressed, false))
    }
    
  case .confirmationPressed:
    
    return .run { [profile = state.userProfile, peers = state.peers, beacons = state.beacons] send in
      
      let closestBeacon = beacons
        .filter { $0.proximity == .immediate || $0.proximity == .near }
        .max { $0.accuracy < $1.accuracy && $0.rssi > $1.rssi }!
      
      let closestPeer = peers.first {
        $0.name == "\(String(format: "%016d-%016d", closestBeacon.major, closestBeacon.minor))"
      }!
      
      async let sending: Void = environment.multipeer.send(profile, closestPeer)
      async let receivedProfile = environment.multipeer.receive(closestPeer)
      
      _ = try await (sending, receivedProfile)
      
      await send(.receivedProfileResponse(receivedProfile))
      
      
    } catch: { error, send in
      print("send/receive error", error.localizedDescription)
    }
    
  case let .receivedProfileResponse(profile):
    state.peerProfile = profile
    
    return .none
    
  case .binding:
    return .none
  }
}
  .debug()
  .binding()


struct ContentView: View {
  let store: Store<P2PState, P2PAction>
  @ObservedObject var viewStore: ViewStore<P2PState, P2PAction>
  
  init(store: Store<P2PState, P2PAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
  }
  
  var body: some View {
    VStack {
      Button("Start") {
        viewStore.send(.task)
      }
      Button("Share") {
        viewStore.send(.shareButtonPressed)
      }
      
      Toggle(isOn: viewStore.binding(\.$isBeaconTwo)) {
        Text("Beacon Two")
      }
    }
    .buttonStyle(.bordered)
    .sheet(isPresented: viewStore.binding(\.$shareButtonPressed)) {
      if let profile = viewStore.peerProfile {
        Text(profile.name)
      } else {
        Button("Send and Receive") {
          viewStore.send(.confirmationPressed)
        }
        .buttonStyle(.bordered)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: Store(
        initialState: .init(),
        reducer: p2pReducer,
        environment: .init(beacon: BeaconClient(start: { _, _ in .finished }), multipeer: MultipeerClient(start: { _ in .finished }, send: { _, _ in }, receive: { _ in UserProfile(name: "Nikita Mounier")}), orientation: .live, proximitySensor: .live)
      )
    )
  }
}
