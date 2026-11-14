import Foundation
#if os(iOS)
import UIKit
#endif

/// A link that an installed app claims (a universal link: Instagram, Google Maps, Google Photos,
/// WhatsApp, ...) opens in that app, as Beeper does; app.contract's openLink shows any other in
/// the in-app browser. iOS knows which apps claim which links, so no list of sites is kept here.
extension Matrix {
    @MainActor func openInApp(_ request: [String: Any]) async -> [String: Any] {
        let text = request["url"] as? String ?? ""
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            return ["url": text, "opened": false]
        }
        #if os(iOS)
        // under the agent another app would suspend the drive: the link stays in the app.
        if context.agent { return ["url": text, "opened": false] }
        let opened = await withCheckedContinuation { (done: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { done.resume(returning: $0) }
        }
        return ["url": text, "opened": opened]
        #else
        return ["url": text, "opened": false]
        #endif
    }
}
