import UIKit

// a native color picker edits a draft. only use color commits it to the app's local setting.
final class AccentPickerInstance: ExactNativeInstance {
    private let button = UIButton(type: .system)
    private var selected = UIColor.systemBlue
    private weak var presented: UINavigationController?

    override var view: ExactNativeView { button }

    init(_ props: [String: String], _ events: ExactNativeEvents) {
        super.init(events: events)
        button.setTitle("Choose…", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityLabel = "Custom accent color"
        button.addAction(UIAction { [weak self] _ in self?.openPicker() }, for: .touchUpInside)
        try? setProps(props)
        events.intrinsicSize(CGSize(width: 100, height: 44))
    }

    override func setProps(_ props: [String: String]) throws {
        let value = props["selected"] ?? "#007aff"
        if let hex = UInt32(value.dropFirst(), radix: 16) {
            selected = UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                               green: CGFloat((hex >> 8) & 255) / 255,
                               blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }

    private func openPicker() {
        guard presented == nil, var host = button.window?.rootViewController else { return }
        while let next = host.presentedViewController { host = next }
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = selected
        picker.title = "Accent Color"
        picker.navigationItem.title = ""
        let navigation = UINavigationController(rootViewController: picker)
        navigation.isModalInPresentation = true
        picker.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", primaryAction: UIAction { [weak navigation] _ in
            navigation?.dismiss(animated: true)
        })
        picker.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Use Color", primaryAction: UIAction { [weak self, weak navigation, weak picker] _ in
            guard let self, let picker else { return }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard picker.selectedColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
            func channel(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
            let hex = String(format: "#%02x%02x%02x", channel(r), channel(g), channel(b))
            self.events.message(hex)
            navigation?.dismiss(animated: true)
        })
        presented = navigation
        host.present(navigation, animated: true)
    }

    override func destroy() { presented?.dismiss(animated: false) }
}
