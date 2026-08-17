import Flutter
import UIKit
import UserNotifications
import AVFoundation

class SilentAudioPlayer {
  static let shared = SilentAudioPlayer()
  private var audioPlayer: AVAudioPlayer?

  private init() {}

  func start() {
    guard audioPlayer == nil else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)

      let wavData = createSilentWavData()
      audioPlayer = try AVAudioPlayer(data: wavData)
      audioPlayer?.numberOfLoops = -1
      audioPlayer?.volume = 0.01
      audioPlayer?.prepareToPlay()
      audioPlayer?.play()
    } catch {
      print("Failed to start silent audio keeper: \(error)")
    }
  }

  func stop() {
    guard audioPlayer != nil else { return }
    audioPlayer?.stop()
    audioPlayer = nil
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {}
  }

  private func createSilentWavData() -> Data {
    let sampleRate: Int32 = 8000
    let numChannels: Int16 = 1
    let bitsPerSample: Int16 = 16
    let numSamples: Int32 = 8000
    let byteRate = sampleRate * Int32(numChannels * bitsPerSample / 8)
    let blockAlign = numChannels * bitsPerSample / 8
    let dataSize = numSamples * Int32(blockAlign)
    let chunkSize = 36 + dataSize

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    let subchunk1Size: Int32 = 16
    let audioFormat: Int16 = 1
    data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Data($0) })
    data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
    data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
    data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
    data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
    data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
    data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
    data.append(contentsOf: "data".utf8)
    data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
    data.append(Data(count: Int(dataSize)))

    return data
  }
}

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

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.hentaicosplay/background_keeper",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "enableBackground" {
          if let enable = call.arguments as? Bool, enable {
            SilentAudioPlayer.shared.start()
          } else {
            SilentAudioPlayer.shared.stop()
          }
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
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
