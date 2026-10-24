import Flutter
import UIKit
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OunHealthAuthorization") else { return }
    let channel = FlutterMethodChannel(name: "oun/health_workouts", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "available":
        result(HKHealthStore.isHealthDataAvailable())
      case "authorizationNeeded":
        guard HKHealthStore.isHealthDataAvailable() else { result(false); return }
        HKHealthStore().getRequestStatusForAuthorization(toShare: [], read: [HKObjectType.workoutType()]) { status, error in
          DispatchQueue.main.async {
            if error != nil {
              result(FlutterError(code: "health_status", message: "건강 앱 상태를 확인하지 못했어요", details: nil))
            } else {
              // .unnecessary includes previous denial: it is NOT read authorization.
              result(status == .shouldRequest)
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
