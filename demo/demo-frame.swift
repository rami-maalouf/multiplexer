import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { fatalError("usage: demo-frame <new-output.png>") }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard !FileManager.default.fileExists(atPath: url.path) else { fatalError("output already exists") }
let image = NSImage(size: NSSize(width: 1600, height: 1440))
image.lockFocus()
NSColor(red: 12 / 255, green: 17 / 255, blue: 24 / 255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1600, height: 1440).fill()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let heading: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 36, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
let caption: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.lightGray, .paragraphStyle: paragraph]
("Mux" as NSString).draw(in: NSRect(x: 164, y: 1357, width: 588, height: 48), withAttributes: heading)
("Beeper" as NSString).draw(in: NSRect(x: 848, y: 1357, width: 588, height: 48), withAttributes: heading)
("same iPhone · same workflow · inbox content hidden" as NSString).draw(in: NSRect(x: 100, y: 12, width: 1400, height: 28), withAttributes: caption)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: url, options: .withoutOverwriting)
