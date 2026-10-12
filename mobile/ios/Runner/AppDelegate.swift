import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TODO: Replace with a real Google Maps SDK for iOS API key before release.
    // Create one at https://console.cloud.google.com/google/maps-apis and restrict
    // it to this app's bundle identifier. Without a valid key here, GMSMapView
    // renders a blank grey grid instead of map tiles.
    GMSServices.provideAPIKey("YOUR_IOS_GOOGLE_MAPS_API_KEY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The URL schemes in Info.plist — "Continue with Google" checks its
    // scheme is registered before showing (Google's SDK crashes without it).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShobujAppInfo") {
      let channel = FlutterMethodChannel(
        name: "shobuj/app_info", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "urlSchemes" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        result(types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] })
      }
    }
  }
}
