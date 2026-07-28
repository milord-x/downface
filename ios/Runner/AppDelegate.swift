import Combine
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let faceTracker = FaceTracker()
  private let flutterEngine = FlutterEngine(name: "downface_engine")
  private var themeSubscription: AnyCancellable?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    if let registrar = flutterEngine.registrar(forPlugin: "FaceTracker") {
      faceTracker.register(with: registrar)
    }
    NativeUIBridge.shared.attach(messenger: flutterEngine.binaryMessenger)

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.overrideUserInterfaceStyle = ThemeManager.shared.theme.userInterfaceStyle
    window?.rootViewController = NativeRootViewController()
    window?.makeKeyAndVisible()

    themeSubscription = ThemeManager.shared.$theme.sink { [weak self] theme in
      self?.window?.overrideUserInterfaceStyle = theme.userInterfaceStyle
    }

    return true
  }
}
