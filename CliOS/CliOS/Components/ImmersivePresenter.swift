import SwiftUI

// MARK: - Immersive Hosting Controller

/// UIHostingController subclass that requests full immersive mode:
/// - Hides status bar
/// - Auto-hides home indicator
/// - Defers system gestures on top+bottom edges
/// - Disables idle timer
///
/// Uses AnyView to avoid a generic UIHostingController subclass which
/// triggers a Swift compiler crash (segfault in IR emission for deinit)
/// when built with -O (Release optimisation) on Xcode 26 beta.
final class ImmersiveHostingController: UIHostingController<AnyView> {

    override var prefersStatusBarHidden: Bool { true }

    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.top, .bottom] }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: - SwiftUI Wrapper

/// Presents a SwiftUI view in fullscreen immersive mode via UIKit,
/// suppressing Dynamic Island Live Activities.
///
/// Usage:
/// ```
/// .fullScreenCover(isPresented: $showImmersive) {
///     ImmersiveView {
///         MyContentView()
///     }
/// }
/// ```
struct ImmersiveView<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> ImmersiveHostingController {
        let controller = ImmersiveHostingController(rootView: AnyView(content))
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ uiViewController: ImmersiveHostingController, context: Context) {
        uiViewController.rootView = AnyView(content)
    }
}

// MARK: - View Modifier

extension View {
    /// Presents this view in immersive mode that suppresses Dynamic Island.
    func immersiveFullScreen(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            ImmersiveView {
                self
            }
            .ignoresSafeArea()
        }
    }
}
