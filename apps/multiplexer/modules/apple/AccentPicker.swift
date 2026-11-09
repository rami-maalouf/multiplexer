#if os(iOS)
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
#else
import AppKit

// on the mac the shared color panel is the picker. it commits a color when the drag ends
// (`isContinuous` off), and Cancel is simply closing the panel.
final class AccentPickerInstance: ExactNativeInstance {
    private let button = NSButton(title: "Choose…", target: nil, action: nil)
    private let target = AccentPanelTarget()
    private var selected = NSColor.systemBlue
    private var opened = false

    override var view: ExactNativeView { button }

    init(_ props: [String: String], _ events: ExactNativeEvents) {
        super.init(events: events)
        button.bezelStyle = .push
        button.setAccessibilityLabel("Custom accent color")
        target.open = { [weak self] in self?.openPanel() }
        target.picked = { [weak self] color in self?.picked(color) }
        button.target = target
        button.action = #selector(AccentPanelTarget.openPanel)
        try? setProps(props)
        events.intrinsicSize(button.intrinsicContentSize)
    }

    override func setProps(_ props: [String: String]) throws {
        let value = props["selected"] ?? "#007aff"
        if let hex = UInt32(value.dropFirst(), radix: 16) {
            selected = NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                               green: CGFloat((hex >> 8) & 255) / 255,
                               blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }

    private func openPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = false
        panel.title = "Accent Color"
        panel.setTarget(nil)
        panel.color = selected
        panel.setTarget(target)
        panel.setAction(#selector(AccentPanelTarget.colorChanged(_:)))
        opened = true
        panel.makeKeyAndOrderFront(nil)
    }

    private func picked(_ color: NSColor) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        func channel(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        selected = rgb
        events.message(String(format: "#%02x%02x%02x", channel(rgb.redComponent), channel(rgb.greenComponent), channel(rgb.blueComponent)))
    }

    override func destroy() {
        guard opened else { return }
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.orderOut(nil)
    }
}

private final class AccentPanelTarget: NSObject {
    var open: () -> Void = {}
    var picked: (NSColor) -> Void = { _ in }
    @objc func openPanel() { open() }
    @objc func colorChanged(_ panel: NSColorPanel) { picked(panel.color) }
}
#endif
