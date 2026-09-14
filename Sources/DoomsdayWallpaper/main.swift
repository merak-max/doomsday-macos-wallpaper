import AppKit
import Foundation

private struct AppConfiguration: Codable {
    let targetDate: String
    let startDate: String
    let title: String
}

private struct CountdownProgress {
    let targetDate: Date
    let title: String
    let totalDays: Int
    let elapsedDays: Int
    let remainingDays: Int
    let yearsLeft: Int
    let monthsLeft: Int
    let daysLeft: Int

    var percentComplete: Int {
        guard totalDays > 0 else { return 100 }
        return min(100, Int((Double(elapsedDays) / Double(totalDays) * 100).rounded(.down)))
    }
}

private enum WallpaperError: LocalizedError {
    case noScreens
    case cannotCreateBitmap
    case cannotEncodePNG
    case missingConfiguration
    case invalidDate(String)
    case targetNotFuture(String)

    var errorDescription: String? {
        switch self {
        case .noScreens: return "No active displays were found."
        case .cannotCreateBitmap: return "Could not create the wallpaper image buffer."
        case .cannotEncodePNG: return "Could not encode the wallpaper as PNG."
        case .missingConfiguration: return "No countdown is configured. Run configure.sh with a target date first."
        case .invalidDate(let value): return "Invalid date '\(value)'. Use YYYY-MM-DD, for example 2030-01-01."
        case .targetNotFuture(let value): return "Target date \(value) must be later than today."
        }
    }
}

private var calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = .autoupdatingCurrent
    return value
}()

private let supportDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/DoomsdayWallpaper", isDirectory: true)
private let configurationURL = supportDirectory.appendingPathComponent("config.json")

private func makeDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    return formatter
}

private func parseDate(_ value: String) throws -> Date {
    let formatter = makeDateFormatter()
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
        throw WallpaperError.invalidDate(value)
    }
    return calendar.startOfDay(for: date)
}

private func saveConfiguration(targetDate: String, title: String) throws {
    let target = try parseDate(targetDate)
    let today = calendar.startOfDay(for: Date())
    guard target > today else { throw WallpaperError.targetNotFuture(targetDate) }

    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let configuration = AppConfiguration(
        targetDate: targetDate,
        startDate: makeDateFormatter().string(from: today),
        title: cleanTitle.isEmpty ? "COUNTDOWN" : cleanTitle
    )

    try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(configuration).write(to: configurationURL, options: .atomic)
    print("Configured '\(configuration.title)' for \(configuration.targetDate)")
}

private func loadConfiguration() throws -> AppConfiguration {
    guard FileManager.default.fileExists(atPath: configurationURL.path) else {
        throw WallpaperError.missingConfiguration
    }
    return try JSONDecoder().decode(AppConfiguration.self, from: Data(contentsOf: configurationURL))
}

private func countdownProgress(configuration: AppConfiguration, now: Date = Date()) throws -> CountdownProgress {
    let today = calendar.startOfDay(for: now)
    let startDate = try parseDate(configuration.startDate)
    let targetDate = try parseDate(configuration.targetDate)
    let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 1)
    let rawElapsed = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
    let elapsedDays = min(totalDays, max(0, rawElapsed))
    let remainingDays = max(0, calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0)

    let components = today < targetDate
        ? calendar.dateComponents([.year, .month, .day], from: today, to: targetDate)
        : DateComponents(year: 0, month: 0, day: 0)

    return CountdownProgress(
        targetDate: targetDate,
        title: configuration.title,
        totalDays: totalDays,
        elapsedDays: elapsedDays,
        remainingDays: remainingDays,
        yearsLeft: components.year ?? 0,
        monthsLeft: components.month ?? 0,
        daysLeft: components.day ?? 0
    )
}

private func displayPixelSize(for screen: NSScreen) -> CGSize {
    let scale = max(screen.backingScaleFactor, 1)
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

private func gridDimensions(totalDots: Int, availableSize: CGSize) -> (columns: Int, rows: Int, gap: CGFloat) {
    let aspect = max(0.5, availableSize.width / availableSize.height)
    let columns = max(1, min(totalDots, Int(ceil(sqrt(Double(totalDots) * Double(aspect))))))
    let rows = max(1, Int(ceil(Double(totalDots) / Double(columns))))
    let horizontalGap = columns > 1 ? availableSize.width / CGFloat(columns - 1) : availableSize.width
    let verticalGap = rows > 1 ? availableSize.height / CGFloat(rows - 1) : availableSize.height
    return (columns, rows, min(horizontalGap, verticalGap))
}

private func renderWallpaper(size: CGSize, progress: CountdownProgress) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
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

    NSColor(calibratedWhite: 0.008, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    let referenceScale = min(size.width / 2560, size.height / 1664)
    let availableGridSize = CGSize(width: size.width * 0.58, height: size.height * 0.46)
    let grid = gridDimensions(totalDots: progress.totalDays, availableSize: availableGridSize)
    let gap = min(grid.gap, max(18, 25 * referenceScale))
    let radius = max(1.4, min(6.2 * referenceScale, gap * 0.24))
    let gridWidth = CGFloat(grid.columns - 1) * gap
    let gridHeight = CGFloat(grid.rows - 1) * gap
    let gridStartX = (size.width - gridWidth) / 2
    let gridCenterY = size.height * 0.52
    let gridTopY = gridCenterY + gridHeight / 2

    let elapsedColor = NSColor(calibratedWhite: 0.28, alpha: 0.72)
    let remainingColor = NSColor(calibratedRed: 1, green: 0.47, blue: 0.02, alpha: 0.84)
    let todayColor = NSColor(calibratedWhite: 1, alpha: 1)

    for index in 0..<progress.totalDays {
        let row = index / grid.columns
        let column = index % grid.columns
        let center = NSPoint(
            x: gridStartX + CGFloat(column) * gap,
            y: gridTopY - CGFloat(row) * gap
        )

        let dotRadius: CGFloat
        let dotColor: NSColor
        if index < progress.elapsedDays {
            dotRadius = radius
            dotColor = elapsedColor
        } else if index == progress.elapsedDays && progress.remainingDays > 0 {
            dotRadius = radius * 1.55
            dotColor = todayColor
        } else {
            dotRadius = radius
            dotColor = remainingColor
        }

        dotColor.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: center.x - dotRadius,
            y: center.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )).fill()
    }

    let accent = NSColor(calibratedRed: 1, green: 0.52, blue: 0.04, alpha: 1)
    let titleFont = NSFont.monospacedSystemFont(ofSize: max(14, 17 * referenceScale), weight: .semibold)
    let dateFont = NSFont.monospacedSystemFont(ofSize: max(11, 14 * referenceScale), weight: .medium)
    let summaryFont = NSFont.monospacedSystemFont(ofSize: max(27, 35 * referenceScale), weight: .semibold)
    let detailFont = NSFont.monospacedSystemFont(ofSize: max(11, 14 * referenceScale), weight: .regular)

    let displayDateFormatter = DateFormatter()
    displayDateFormatter.calendar = calendar
    displayDateFormatter.locale = Locale(identifier: "en_US_POSIX")
    displayDateFormatter.dateFormat = "d MMMM yyyy"

    drawCenteredText(
        progress.title.uppercased(),
        atY: gridTopY + max(70, 88 * referenceScale),
        canvasWidth: size.width,
        font: titleFont,
        color: NSColor(calibratedWhite: 0.9, alpha: 0.96),
        tracking: 4 * referenceScale
    )
    drawCenteredText(
        "UNTIL  \(displayDateFormatter.string(from: progress.targetDate).uppercased())",
        atY: gridTopY + max(43, 55 * referenceScale),
        canvasWidth: size.width,
        font: dateFont,
        color: NSColor(calibratedWhite: 0.52, alpha: 0.9),
        tracking: 3 * referenceScale
    )
    drawCenteredText(
        "\(progress.yearsLeft)Y  ·  \(progress.monthsLeft)M  ·  \(progress.daysLeft)D  LEFT",
        atY: gridTopY - gridHeight - max(58, 72 * referenceScale),
        canvasWidth: size.width,
        font: summaryFont,
        color: accent,
        tracking: 0.5 * referenceScale
    )
    drawCenteredText(
        "\(progress.remainingDays) DAYS REMAINING  ·  \(progress.percentComplete)% ELAPSED",
        atY: gridTopY - gridHeight - max(94, 116 * referenceScale),
        canvasWidth: size.width,
        font: detailFont,
        color: NSColor(calibratedWhite: 0.48, alpha: 0.88),
        tracking: 1.5 * referenceScale
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
    try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

    let progress = try countdownProgress(configuration: loadConfiguration())
    let refreshID = UUID().uuidString.lowercased()
    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
        .allowClipping: false,
        .fillColor: NSColor.black
    ]

    for (index, screen) in screens.enumerated() {
        let outputURL = supportDirectory.appendingPathComponent("wallpaper-display-\(index + 1)-\(refreshID).png")
        try renderWallpaper(size: displayPixelSize(for: screen), progress: progress)
            .write(to: outputURL, options: .atomic)
        try NSWorkspace.shared.setDesktopImageURL(outputURL, for: screen, options: options)
        print("Set display \(index + 1): \(outputURL.path)")
    }

    print("\(progress.title): \(progress.yearsLeft)y \(progress.monthsLeft)m \(progress.daysLeft)d (\(progress.remainingDays) days) left")
}

private func printUsage() {
    print("""
    Doomsday Wallpaper

    Usage:
      doomsday-wallpaper                         Refresh the wallpaper
      doomsday-wallpaper --configure DATE TITLE  Set a new countdown
      doomsday-wallpaper --help                  Show this help

    DATE must use YYYY-MM-DD format. TITLE is optional.
    """)
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.first == "--help" || arguments.first == "-h" {
        printUsage()
    } else if arguments.first == "--configure" {
        guard arguments.count >= 2 else {
            printUsage()
            throw WallpaperError.invalidDate("")
        }
        try saveConfiguration(
            targetDate: arguments[1],
            title: arguments.count >= 3 ? arguments[2] : "COUNTDOWN"
        )
        try setWallpaper()
    } else if arguments.isEmpty {
        try setWallpaper()
    } else {
        printUsage()
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("Doomsday Wallpaper: \(error.localizedDescription)\n".utf8))
    exit(1)
}
