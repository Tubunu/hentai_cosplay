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
  private var isSetup = false

  func setup(with view: UIView) {
    guard !isSetup, AVPictureInPictureController.isPictureInPictureSupported() else { return }
    isSetup = true

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {}

    guard let videoUrl = createOrGetPipVideoUrl() else { return }
    let playerItem = AVPlayerItem(url: videoUrl)
    player = AVQueuePlayer(playerItem: playerItem)
    if let player = player {
      playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
    }

    let layer = AVPlayerLayer(player: player)
    layer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
    layer.isHidden = false
    layer.opacity = 0.01
    view.layer.addSublayer(layer)
    self.playerLayer = layer

    if let playerLayer = self.playerLayer {
      pipController = AVPictureInPictureController(playerLayer: playerLayer)
      pipController?.delegate = self

      if #available(iOS 14.2, *) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
      }
    }
  }

  func startPip() {
    guard let pipController = pipController, AVPictureInPictureController.isPictureInPictureSupported() else { return }
    player?.play()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if !pipController.isPictureInPictureActive {
        pipController.startPictureInPicture()
      }
    }
  }

  func stopPip() {
    pipController?.stopPictureInPicture()
    player?.pause()
  }

  func isSupported() -> Bool {
    return AVPictureInPictureController.isPictureInPictureSupported()
  }

  private func createOrGetPipVideoUrl() -> URL? {
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
    let videoUrl = tempDir.appendingPathComponent("hc_pip_loop.mp4")

    if fileManager.fileExists(atPath: videoUrl.path) {
      return videoUrl
    }

    guard let writer = try? AVAssetWriter(outputURL: videoUrl, fileType: .mp4) else { return nil }
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: 320,
      AVVideoHeightKey: 240
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: writerInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: 320,
        kCVPixelBufferHeightKey as String: 240
      ]
    )
    writer.add(writerInput)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32ARGB, nil, &buffer)
    if status == kCVReturnSuccess, let buffer = buffer {
      CVPixelBufferLockBaseAddress(buffer, [])
      if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
        memset(baseAddress, 0x1A, 320 * 240 * 4)
      }
      CVPixelBufferUnlockBaseAddress(buffer, [])

      for i in 0..<30 {
        while !writerInput.isReadyForMoreMediaData {
          Thread.sleep(forTimeInterval: 0.01)
        }
        let presentationTime = CMTime(value: Int64(i * 100), timescale: 1500)
        adaptor.append(buffer, withPresentationTime: presentationTime)
      }
    }

    writerInput.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
      semaphore.signal()
    }
    semaphore.wait()
    return videoUrl
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
          PipDownloadManager.shared.startPip()
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
      PipDownloadManager.shared.startPip()
    }

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
