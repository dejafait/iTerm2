//
//  iTermColorMapResolveTests.swift
//  ModernTests
//
//  Tests for iTermColorMap.resolvedColorValue: and resolvedDualModeColor:.
//

import XCTest
@testable import iTerm2SharedARC

final class iTermColorMapResolveTests: XCTestCase {

    private func makeMap(backgroundIsDark: Bool) -> iTermColorMap {
        let map = iTermColorMap()
        // setColor:forKey: with kColorMapBackground updates _backgroundBrightness
        // from the color's perceivedBrightness. Pick saturated black or white
        // for an unambiguous threshold (perceivedBrightness uses BT.709).
        let bg = backgroundIsDark ? NSColor.black : NSColor.white
        map.setColor(bg, forKey: Int32(kColorMapBackground))
        return map
    }

    func testResolvedColorValuePassesThroughWhenNoDarkVariant() {
        let map = makeMap(backgroundIsDark: false)
        let v = VT100TerminalColorValue(red: 11, green: 22, blue: 33, mode: ColorMode24bit,
                                        hasDarkVariant: false, redDark: 0, greenDark: 0, blueDark: 0)
        let r = map.resolvedColorValue(v)
        XCTAssertFalse(r.hasDarkVariant.boolValue)
        XCTAssertEqual(r.red, 11)
        XCTAssertEqual(r.green, 22)
        XCTAssertEqual(r.blue, 33)
    }

    func testResolvedColorValuePicksLightOnLightBackground() {
        let map = makeMap(backgroundIsDark: false)
        let v = VT100TerminalColorValue(red: 11, green: 22, blue: 33, mode: ColorMode24bit,
                                        hasDarkVariant: true, redDark: 44, greenDark: 55, blueDark: 66)
        let r = map.resolvedColorValue(v)
        XCTAssertFalse(r.hasDarkVariant.boolValue)
        XCTAssertEqual(r.red, 11)
        XCTAssertEqual(r.green, 22)
        XCTAssertEqual(r.blue, 33)
    }

    func testResolvedColorValuePicksDarkOnDarkBackground() {
        let map = makeMap(backgroundIsDark: true)
        let v = VT100TerminalColorValue(red: 11, green: 22, blue: 33, mode: ColorMode24bit,
                                        hasDarkVariant: true, redDark: 44, greenDark: 55, blueDark: 66)
        let r = map.resolvedColorValue(v)
        XCTAssertFalse(r.hasDarkVariant.boolValue)
        XCTAssertEqual(r.red, 44)
        XCTAssertEqual(r.green, 55)
        XCTAssertEqual(r.blue, 66)
    }

    // The 24-bit fast path in fastColorForKey:colorSpace: must be bit-identical to
    // the full colorUsingColorSpace: conversion when the target space is the app's
    // native 8-bit space, since it skips that conversion.
    func test24BitFastPathMatchesConversionInNativeSpace() {
        let map = iTermColorMap()
        let native: NSColorSpace = iTermAdvancedSettingsModel.p3() ? .displayP3 : .sRGB
        let red: Int32 = 200, green: Int32 = 100, blue: Int32 = 50
        let key = iTermColorMap.keyFor8bitRed(red, green: green, blue: blue)

        let fast = map.fastColor(forKey: key, colorSpace: native)

        guard let color = NSColor(red, green: green, blue: blue)
            .usingColorSpace(native) else {
            XCTFail("reference conversion failed")
            return
        }
        XCTAssertEqual(fast.x, Float(color.redComponent), accuracy: 1e-5, "red")
        XCTAssertEqual(fast.y, Float(color.greenComponent), accuracy: 1e-5, "green")
        XCTAssertEqual(fast.z, Float(color.blueComponent), accuracy: 1e-5, "blue")
        XCTAssertEqual(fast.w, 1, accuracy: 1e-5, "alpha")
    }

    // The mode field must survive resolution — both light and dark share it.
    func testResolvedColorValuePreservesMode() {
        let map = makeMap(backgroundIsDark: true)
        let v = VT100TerminalColorValue(red: 7, green: 0, blue: 0, mode: ColorModeNormal,
                                        hasDarkVariant: true, redDark: 9, greenDark: 0, blueDark: 0)
        let r = map.resolvedColorValue(v)
        XCTAssertEqual(r.mode, ColorModeNormal)
        XCTAssertEqual(r.red, 9)
    }
}


final class MonochromeTerminalTests: XCTestCase {
    private func assertColor(_ color: NSColor?, _ value: CGFloat,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let color = color?.usingColorSpace(.sRGB) else {
            XCTFail("Missing RGB color", file: file, line: line)
            return
        }
        XCTAssertEqual(color.redComponent, value, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(color.greenComponent, value, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(color.blueComponent, value, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.0001, file: file, line: line)
    }

    func testAllANSIAndTruecolorTextIgnoreFaintAndDimming() {
        let map = iTermColorMap()
        map.monochromeTerminal = 1
        map.dimmingAmount = 0.8
        map.mutingAmount = 0.9
        map.faintTextAlpha = 0.1
        for index in 0..<256 {
            assertColor(map.color(forCode: Int32(index), green: 0, blue: 0,
                                  colorMode: ColorModeNormal, bold: true, faint: true,
                                  isBackground: false, useCustomBoldColor: true, brightenBold: true), 0)
            assertColor(map.color(forCode: Int32(index), green: 0, blue: 0,
                                  colorMode: ColorModeNormal, bold: false, faint: false,
                                  isBackground: true, useCustomBoldColor: false, brightenBold: false), 1)
        }
        for mode in [ColorMode24bit, ColorModeExternal] {
            assertColor(map.color(forCode: 245, green: 130, blue: 250, colorMode: mode,
                                  bold: false, faint: true, isBackground: false,
                                  useCustomBoldColor: false, brightenBold: false), 0)
        }
        assertColor(map.processedTextColor(forTextColor: .lightGray, overBackgroundColor: .white,
                                          disableMinimumContrast: true), 0)
        assertColor(map.processedBackgroundColor(forBackgroundColor: .white), 1)
        let background = map.fastProcessedBackgroundColor(forBackgroundColor: SIMD4<Float>(1, 1, 1, 0.2))
        XCTAssertEqual(background, SIMD4<Float>(1, 1, 1, 1))
    }

    func testBothPolaritiesKeepHighlightsAndCursorReadable() {
        let map = iTermColorMap()
        for mode in [1, 2] {
            map.monochromeTerminal = mode
            let ink: CGFloat = mode == 1 ? 0 : 1
            assertColor(map.color(forKey: Int32(kColorMapForeground)), ink)
            assertColor(map.color(forKey: Int32(kColorMapBackground)), 1 - ink)
            assertColor(map.color(forKey: Int32(kColorMapCursor)), ink)
            assertColor(map.color(forKey: Int32(kColorMapCursorText)), 1 - ink)
            assertColor(map.color(forKey: Int32(kColorMapSelection)), ink)
            assertColor(map.monochromeColor(forForeground: true, highlighted: true), 1 - ink)
            assertColor(map.monochromeColor(forForeground: false, highlighted: true), ink)
            let fast = map.fastColor(forKey: Int32(kColorMapBackground), colorSpace: .sRGB)
            XCTAssertEqual(fast.x, Float(1 - ink), accuracy: 0.0001)
            XCTAssertEqual(fast.w, 1)
            XCTAssertEqual(map.backgroundIsDark, mode == 2)
        }
    }

    func testLiveToggleRestoresStoredColorsAndInvalidatesSnapshots() {
        let map = iTermColorMap()
        let original = NSColor(srgbRed: 0.3, green: 0.4, blue: 0.7, alpha: 1)
        map.setColor(original, forKey: Int32(kColorMapBackground))
        _ = map.fastColor(forKey: Int32(kColorMapBackground), colorSpace: .sRGB)
        let generation = map.generation
        map.monochromeTerminal = 1
        XCTAssertGreaterThan(map.generation, generation)
        let snapshot = map.copy()!
        map.monochromeTerminal = 2
        XCTAssertEqual(snapshot.monochromeTerminal, 1)
        map.monochromeTerminal = 0
        let restoredColor = map.color(forKey: Int32(kColorMapBackground))!.usingColorSpace(.sRGB)!
        XCTAssertEqual(restoredColor.redComponent, 0.3, accuracy: 0.0001)
        XCTAssertEqual(restoredColor.greenComponent, 0.4, accuracy: 0.0001)
        XCTAssertEqual(restoredColor.blueComponent, 0.7, accuracy: 0.0001)
        let restored = map.fastColor(forKey: Int32(kColorMapBackground), colorSpace: .sRGB)
        XCTAssertEqual(restored.z, 0.7, accuracy: 0.0001)
        map.monochromeTerminal = 99
        XCTAssertEqual(map.monochromeTerminal, 0)
    }

    func testModeParticipatesInScreenConfigurationSnapshots() {
        let config = VT100MutableScreenConfiguration()
        config.monochromeTerminal = 1
        XCTAssertTrue(config.dirtyKeyPaths().contains("monochromeTerminal"))
        let snapshot = config.copy() as! VT100ScreenConfiguration
        config.monochromeTerminal = 2
        XCTAssertEqual(snapshot.monochromeTerminal, 1)
        XCTAssertEqual(config.monochromeTerminal, 2)
    }

    func testMonochromeRenderingIllustration() throws {
        let map = iTermColorMap()
        let image = NSImage(size: NSSize(width: 1000, height: 240))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1000, height: 240).fill()
        let font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        for (column, mode) in [0, 1].enumerated() {
            map.monochromeTerminal = mode
            let title = mode == 0 ? "Profile colors" : "Monochrome: black on white"
            (title as NSString).draw(at: NSPoint(x: 20 + column * 500, y: 195),
                withAttributes: [.font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: NSColor.black])
            for (row, color) in [NSColor.lightGray, .systemBlue, .systemRed, .gray].enumerated() {
                let ink = mode == 0 ? color : map.processedTextColor(forTextColor: color,
                           overBackgroundColor: .white, disableMinimumContrast: true)!
                ("Sample terminal text — line \(row + 1)" as NSString).draw(
                    at: NSPoint(x: 20 + column * 500, y: 150 - row * 38),
                    withAttributes: [.font: font, .foregroundColor: ink])
            }
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/native-screenshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("monochrome-terminal.png"))
    }
}
