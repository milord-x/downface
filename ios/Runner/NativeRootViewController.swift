import UIKit
import SwiftUI
import Flutter

final class NativeRootViewController: UIHostingController<HomeView> {
    init() {
        super.init(rootView: HomeView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
