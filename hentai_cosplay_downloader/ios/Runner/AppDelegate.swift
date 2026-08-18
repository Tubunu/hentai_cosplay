import Flutter
import UIKit
import UserNotifications
import AVFoundation
import AVKit

class PipDownloadManager: NSObject, AVPictureInPictureControllerDelegate {
  static let shared = PipDownloadManager()

  private var pipController: AVPictureInPictureController?
  private var playerLayer: AVPlayerLayer?
  private var player: AVQueuePlayer?
  private var playerLooper: AVPlayerLooper?
  private var containerView: UIView?
  private var isSetup = false
  private var pipPossibleObservation: NSKeyValueObservation?
  private var shouldStartWhenPossible = false

  func setup(with parentView: UIView?) {
    guard let parentView = parentView, !isSetup, AVPictureInPictureController.isPictureInPictureSupported() else { return }
    isSetup = true

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("AVAudioSession setup error: \(error)")
    }

    guard let videoUrl = getOrCreatePipVideoUrl() else { return }
    let playerItem = AVPlayerItem(url: videoUrl)
    player = AVQueuePlayer(playerItem: playerItem)
    player?.isMuted = true
    if let player = player {
      playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
    }

    let cView = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
    cView.backgroundColor = .black
    cView.alpha = 0.02
    cView.isUserInteractionEnabled = false
    parentView.addSubview(cView)
    self.containerView = cView

    let layer = AVPlayerLayer(player: player)
    layer.frame = cView.bounds
    layer.videoGravity = .resizeAspectFill
    cView.layer.addSublayer(layer)
    self.playerLayer = layer

    if let playerLayer = self.playerLayer {
      pipController = AVPictureInPictureController(playerLayer: playerLayer)
      pipController?.delegate = self

      if #available(iOS 14.2, *) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
      }

      pipPossibleObservation = pipController?.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, _ in
        if controller.isPictureInPicturePossible, self?.shouldStartWhenPossible == true {
          self?.shouldStartWhenPossible = false
          DispatchQueue.main.async {
            controller.startPictureInPicture()
          }
        }
      }
    }
  }

  func startPip(view: UIView? = nil) {
    if !isSetup, let view = view {
      setup(with: view)
    }
    guard let pipController = pipController, AVPictureInPictureController.isPictureInPictureSupported() else { return }
    player?.play()

    if pipController.isPictureInPicturePossible {
      shouldStartWhenPossible = false
      if !pipController.isPictureInPictureActive {
        pipController.startPictureInPicture()
      }
    } else {
      shouldStartWhenPossible = true
      for delay in [0.1, 0.3, 0.6, 1.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
          guard let self = self, let pip = self.pipController else { return }
          if pip.isPictureInPicturePossible && !pip.isPictureInPictureActive {
            self.shouldStartWhenPossible = false
            pip.startPictureInPicture()
          }
        }
      }
    }
  }

  func stopPip() {
    shouldStartWhenPossible = false
    pipController?.stopPictureInPicture()
    player?.pause()
  }

  func isSupported() -> Bool {
    return AVPictureInPictureController.isPictureInPictureSupported()
  }

  private func getOrCreatePipVideoUrl() -> URL? {
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
    let videoUrl = tempDir.appendingPathComponent("hc_pip_keeper.mp4")

    if fileManager.fileExists(atPath: videoUrl.path) {
      return videoUrl
    }

    let base64Video = "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AAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAAAAAtaWxzdAAAACWpdG9vAAAAHWRhdGEAAAABAAAAAExhdmY2Mi4xMi4xMDAAAAAIZnJlZQAABEptZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMyAwNDgwY2IwIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTYgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTEwIHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAOmWIhAAR//73iB8yy2+catdyEeetLq0fUO5GcV6kvf4gAhHyNo1+s9B83ToEdAAAOQG2AVspks3jS4EAAAANQZokbEEP/qpVAACFgN4CAExhdmM2Mi4yOC4xMDAAAjBADgAAAAlBnkJ4h38AAQMBGCAHARggBwEYIAcBGCAHARggBwAAAAkBnmF0Q38AAXcBGCAHARggBwEYIAcBGCAHAAAACQGeY2pDfwABdwEYIAcBGCAHARggBwEYIAcAAAASQZpoSahBaJlMCHf//qmWAAIHARggBwEYIAcBGCAHARggBwEYIAcAAAALQZ6GRREsO/8AAQMBGCAHARggBwEYIAcBGCAHAAAACQGepXRDfwABdwEYIAcBGCAHARggBwEYIAcAAAAJAZ6nakN/AAF3ARggBwEYIAcBGCAHARggBwEYIAcAAAASQZqpSahBbJlMCG///qeEAAP8ARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBw=="

    if let data = Data(base64Encoded: base64Video) {
      try? data.write(to: videoUrl)
      return videoUrl
    }
    return nil
  }
}

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
      audioPlayer?.volume = 0.05
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
    let sampleRate: Int32 = 44100
    let numChannels: Int16 = 1
    let bitsPerSample: Int16 = 16
    let numSamples: Int32 = 44100
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
  private var isDownloadingActive = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      PipDownloadManager.shared.setup(with: controller.view)

      let channel = FlutterMethodChannel(
        name: "com.hentaicosplay/background_keeper",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "enableBackground":
          let enable = (call.arguments as? Bool) ?? false
          self?.isDownloadingActive = enable
          if enable {
            SilentAudioPlayer.shared.start()
          } else {
            SilentAudioPlayer.shared.stop()
            PipDownloadManager.shared.stopPip()
          }
          result(true)
        case "startPip":
          PipDownloadManager.shared.startPip(view: controller.view)
          result(true)
        case "stopPip":
          PipDownloadManager.shared.stopPip()
          result(true)
        case "isPipSupported":
          result(PipDownloadManager.shared.isSupported())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    if isDownloadingActive {
      SilentAudioPlayer.shared.start()
      PipDownloadManager.shared.startPip(view: window?.rootViewController?.view)
    }

    startBackgroundTask(application)
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    endBackgroundTask(application)
  }

  private func startBackgroundTask(_ application: UIApplication) {
    endBackgroundTask(application)
    backgroundTask = application.beginBackgroundTask(withName: "HentaiCosplayDownloadTask") { [weak self] in
      self?.endBackgroundTask(application)
    }
  }

  private func endBackgroundTask(_ application: UIApplication) {
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
