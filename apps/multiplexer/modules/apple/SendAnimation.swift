#if canImport(UIKit)
import UIKit
#endif

extension Matrix {
    // exact's frame() omits the native keyboard-toolbar lift. read the composer's
    // displayed box once at send, scoped to this session, without observing each frame.
    @MainActor func sendOrigin() -> [String: Any] {
        #if canImport(UIKit)
        guard let root = context.sessionView as? UIView else { return unavailableSendOrigin }
        func tagged(_ identifier: String, in view: UIView) -> UIView? {
            guard !view.isHidden, view.window != nil else { return nil }
            if view.accessibilityIdentifier == identifier { return view }
            for child in view.subviews {
                if let found = tagged(identifier, in: child) { return found }
            }
            return nil
        }
        guard let page = tagged("conversation", in: root),
              let field = tagged("composer-glass", in: page) else { return unavailableSendOrigin }
        let box = field.convert(field.bounds, to: root)
        let container = page.convert(page.bounds, to: root)
        return ["available": true, "x": box.minX, "width": box.width, "height": box.height,
                "bottom": box.maxY - container.minY]
        #else
        return unavailableSendOrigin
        #endif
    }
}

private let unavailableSendOrigin: [String: Any] = ["available": false, "x": 0, "width": 0, "height": 0, "bottom": 0]
