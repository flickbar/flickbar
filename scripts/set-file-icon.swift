// Gives a file an icon in Finder: swift scripts/set-file-icon.swift AppIcon.icns Flickbar.dmg
// It lives in an extended attribute, so browsers drop it on download; the mounted disk keeps .VolumeIcon.icns.
import AppKit
let args = CommandLine.arguments
guard NSWorkspace.shared.setIcon(NSImage(contentsOfFile: args[1]), forFile: args[2]) else { fatalError("couldn't set the icon") }
