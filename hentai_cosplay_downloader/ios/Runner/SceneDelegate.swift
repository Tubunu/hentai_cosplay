import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      PipDownloadManager.shared.setup(with: controller.view)
    }
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.handleAppDidEnterBackground()
    }
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.handleAppWillEnterForeground()
    }
  }
}
