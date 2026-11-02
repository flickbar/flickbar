// Gives a file an icon in Finder: swift scripts/set-file-icon.swift AppIcon.icns Flickbar.dmg
// It lives in an extended attribute, so browsers drop it on download; the mounted disk keeps .VolumeIcon.icns.
import AppKit
let args = CommandLine.arguments
// A nil image would clear the icon and still report success.
guard let icon = NSImage(contentsOfFile: args[1]), NSWorkspace.shared.setIcon(icon, forFile: args[2]) else { fatalError("couldn't set the icon") }
