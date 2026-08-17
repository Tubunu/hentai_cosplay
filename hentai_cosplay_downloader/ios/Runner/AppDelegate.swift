import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    backgroundTask = application.beginBackgroundTask(withName: "HentaiCosplayDownloadTask") { [weak self] in
      if let self = self, self.backgroundTask != .invalid {
        application.endBackgroundTask(self.backgroundTask)
        self.backgroundTask = .invalid
      }
    }
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    if backgroundTask != .invalid {
      application.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }
}
