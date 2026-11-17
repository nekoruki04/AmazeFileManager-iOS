// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let win = UIWindow(windowScene: windowScene)
        win.backgroundColor = .systemBackground
        let rootVC = BrowserViewController()
        let nav = UINavigationController(rootViewController: rootVC)
        nav.navigationBar.prefersLargeTitles = true
        win.rootViewController = nav
        win.makeKeyAndVisible()
        self.window = win
    }
}
