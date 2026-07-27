import ARKit
import Flutter

final class FaceTracker: NSObject, ARSessionDelegate, FlutterStreamHandler {
  private let session = ARSession()
  private var eventSink: FlutterEventSink?

  static let isSupported = ARFaceTrackingConfiguration.isSupported

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterEventChannel(
      name: "downface/face_distance",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(self)

    let methodChannel = FlutterMethodChannel(
      name: "downface/face_tracking",
      binaryMessenger: registrar.messenger()
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isSupported":
        result(FaceTracker.isSupported)
      case "start":
        self?.start()
        result(nil)
      case "stop":
        self?.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func start() {
    guard FaceTracker.isSupported else { return }
    session.delegate = self
    let configuration = ARFaceTrackingConfiguration()
    configuration.isLightEstimationEnabled = false
    session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
  }

  private func stop() {
    session.pause()
  }

  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard let anchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
      return
    }
    let faceTransform = anchor.transform
    let cameraTransform = frame.camera.transform

    let dx = faceTransform.columns.3.x - cameraTransform.columns.3.x
    let dy = faceTransform.columns.3.y - cameraTransform.columns.3.y
    let dz = faceTransform.columns.3.z - cameraTransform.columns.3.z
    let distance = Double((dx * dx + dy * dy + dz * dz).squareRoot())
    let timestampMs = Int(frame.timestamp * 1000)

    eventSink?(["distance": distance, "timestampMs": timestampMs])
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    eventSink?(FlutterError(code: "AR_SESSION_ERROR", message: error.localizedDescription, details: nil))
  }
}
