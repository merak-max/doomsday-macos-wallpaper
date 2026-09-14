import AppKit
import CoreGraphics
import Foundation

private struct CountdownProgress {
    let targetDate: Date
    let totalDays: Int
    let elapsedDays: Int
    let remainingDays: Int
    let yearsLeft: Int
    let monthsLeft: Int
    let daysLeft: Int

    var percentComplete: Int {
        guard totalDays > 0 else { return 0 }
        return min(100, Int((Double(elapsedDays) / Double(totalDays) * 100.0).rounded(.down)))
    }
}

private enum WallpaperError: LocalizedError {
    case noScreens
    case cannotCreateBitmap
    case cannotEncodePNG

    var errorDescription: String? {
        switch self {
        case .noScreens:
            return "No active displays were found."
        case .cannotCreateBitmap:
            return "Could not create the wallpaper image buffer."
        case .cannotEncodePNG:
            return "Could not encode the wallpaper as PNG."
        }
    }
}

private var calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = .autoupdatingCurrent
    return value
}()

private func countdownProgress(now: Date = Date()) -> CountdownProgress {
    let today = calendar.startOfDay(for: now)
    let startDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
    let targetDate = calendar.date(from: DateComponents(year: 2028, month: 9, day: 13))!
    let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 1)
    let rawElapsed = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
    let elapsedDays = min(totalDays, max(0, rawElapsed))
    let remainingDays = max(0, calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0)

    let calendarLeft: DateComponents
    if today < targetDate {
        calendarLeft = calendar.dateComponents([.year, .month, .day], from: today, to: targetDate)
    } else {
        calendarLeft = DateComponents(year: 0, month: 0, day: 0)
    }

    return CountdownProgress(
        targetDate: targetDate,
        totalDays: totalDays,
        elapsedDays: elapsedDays,
        remainingDays: remainingDays,
        yearsLeft: calendarLeft.year ?? 0,
        monthsLeft: calendarLeft.month ?? 0,
        daysLeft: calendarLeft.day ?? 0
    )
}

private func displayPixelSize(for screen: NSScreen) -> CGSize {
    let scale = max(screen.backingScaleFactor, 1.0)
    return CGSize(
        width: max(1, (screen.frame.width * scale).rounded()),
        height: max(1, (screen.frame.height * scale).rounded())
    )
}

private func drawCenteredText(
    _ text: String,
    atY y: CGFloat,
    canvasWidth: CGFloat,
    font: NSFont,
    color: NSColor,
    tracking: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: tracking
    ]

    let attributed = NSAttributedString(string: text, attributes: attributes)
    let size = attributed.size()
    attributed.draw(in: NSRect(x: 0, y: y - size.height / 2, width: canvasWidth, height: size.height + 8))
}

private func renderWallpaper(size: CGSize, progress: CountdownProgress) throws -> Data {
    let width = Int(size.width)
    let height = Int(size.height)

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw WallpaperError.cannotCreateBitmap
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: size.width, height: size.height)
    NSColor(calibratedWhite: 0.008, alpha: 1).setFill()
    canvas.fill()

    let referenceScale = min(size.width / 2560.0, size.height / 1664.0)
    let columns = 30
    let rows = Int(ceil(Double(progress.totalDays) / Double(columns)))
    let gap = max(19.0, 24.0 * referenceScale)
    let radius = max(4.5, 5.8 * referenceScale)
    let gridWidth = CGFloat(columns - 1) * gap
    let gridHeight = CGFloat(rows - 1) * gap
    let gridStartX = (size.width - gridWidth) / 2
    let gridCenterY = size.height * 0.52
    let gridTopY = gridCenterY + gridHeight / 2

    let completedColor = NSColor(calibratedWhite: 0.28, alpha: 0.72)
    let futureColor = NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.02, alpha: 0.82)
    let todayColor = NSColor(calibratedWhite: 1.0, alpha: 1.0)

    for index in 0..<progress.totalDays {
        let row = index / columns
        let column = index % columns
        let center = NSPoint(
            x: gridStartX + CGFloat(column) * gap,
            y: gridTopY - CGFloat(row) * gap
        )

        let dotRadius: CGFloat
        let dotColor: NSColor

        if index < progress.elapsedDays {
            dotRadius = radius
            dotColor = completedColor
        } else if index == progress.elapsedDays && progress.remainingDays > 0 {
            dotRadius = radius * 1.55
            dotColor = todayColor
        } else {
            dotRadius = radius
            dotColor = futureColor
        }

        dotColor.setFill()
        NSBezierPath(
            ovalIn: NSRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
        ).fill()
    }

    let accent = NSColor(calibratedRed: 1.0, green: 0.52, blue: 0.04, alpha: 1.0)
    let summaryFont = NSFont.monospacedSystemFont(ofSize: max(28, 35 * referenceScale), weight: .semibold)
    let yearFont = NSFont.monospacedSystemFont(ofSize: max(12, 15 * referenceScale), weight: .medium)

    let targetFormatter = DateFormatter()
    targetFormatter.calendar = calendar
    targetFormatter.locale = Locale(identifier: "en_US_POSIX")
    targetFormatter.dateFormat = "dd MMMM yyyy"

    drawCenteredText(
        "UNTIL  \(targetFormatter.string(from: progress.targetDate).uppercased())",
        atY: gridTopY + max(46, 58 * referenceScale),
        canvasWidth: size.width,
        font: yearFont,
        color: NSColor(calibratedWhite: 0.55, alpha: 0.9),
        tracking: 4 * referenceScale
    )

    drawCenteredText(
        "\(progress.yearsLeft)Y  ·  \(progress.monthsLeft)M  ·  \(progress.daysLeft)D  LEFT",
        atY: gridTopY - gridHeight - max(58, 72 * referenceScale),
        canvasWidth: size.width,
        font: summaryFont,
        color: accent,
        tracking: 0.5 * referenceScale
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw WallpaperError.cannotEncodePNG
    }
    return png
}

private func setWallpaper() throws {
    _ = NSApplication.shared
    let screens = NSScreen.screens
    guard !screens.isEmpty else { throw WallpaperError.noScreens }

    let outputDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DoomsdayWallpaper", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let progress = countdownProgress()
    let filenameFormatter = DateFormatter()
    filenameFormatter.calendar = calendar
    filenameFormatter.locale = Locale(identifier: "en_US_POSIX")
    filenameFormatter.timeZone = calendar.timeZone
    filenameFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let refreshID = filenameFormatter.string(from: Date())
    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
        .allowClipping: false,
        .fillColor: NSColor.black
    ]

    for (index, screen) in screens.enumerated() {
        // A unique URL is intentional: macOS caches desktop images by path and may
        // continue displaying stale pixels when an existing PNG is overwritten.
        let outputURL = outputDirectory.appendingPathComponent(
            "wallpaper-display-\(index + 1)-\(refreshID).png"
        )
        let png = try renderWallpaper(size: displayPixelSize(for: screen), progress: progress)
        try png.write(to: outputURL, options: .atomic)
        try NSWorkspace.shared.setDesktopImageURL(outputURL, for: screen, options: options)
        print("Set display \(index + 1): \(outputURL.path)")
    }

    print("Countdown to 13 September 2028: \(progress.yearsLeft)y \(progress.monthsLeft)m \(progress.daysLeft)d (\(progress.remainingDays) total days) left")
}

do {
    try setWallpaper()
} catch {
    FileHandle.standardError.write(Data("Doomsday Wallpaper: \(error.localizedDescription)\n".utf8))
    exit(1)
}
