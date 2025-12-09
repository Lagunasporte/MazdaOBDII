import UIKit
import SwiftUI

// MARK: - Scene Delegate for iOS

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Create the root view
        let contentView = MainTabView()
            .environmentObject(OBDConnectionManager())
            .environmentObject(EngineMonitor())
            .environmentObject(DiagnosticMode())
            .environmentObject(FuelConsumptionTracker())
            .preferredColorScheme(.dark)

        // Create window
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene has been released by the system
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from inactive to active
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from active to inactive
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called when scene transitions from background to foreground
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called when scene transitions from foreground to background
    }
}
