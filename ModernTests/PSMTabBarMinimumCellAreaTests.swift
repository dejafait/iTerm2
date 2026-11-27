//
//  PSMTabBarMinimumCellAreaTests.swift
//  ModernTests
//
//  -maximumLeftInsetFittingAllCellsMinimallyForWidth: answers "how much of the
//  bar can something else take before a tab stops fitting". It mirrors the
//  branch structure of -cellWidthsForHorizontalArrangementWithOverflow: rather
//  than calling it, which is the one real cost of routing the window name's
//  reservation through the tab bar: two expressions that must agree.
//
//  These tests pin them together: at the predicted inset every cell is still
//  laid out at its promised minimum width, and a point past it the tabs are
//  squeezed under that minimum. They assert the two rules against each other
//  rather than against fixed point values, so they stay true if the metrics
//  change and fail only if the two rules diverge.
//

import XCTest
@testable import iTerm2SharedARC

final class PSMTabBarMinimumCellAreaTests: XCTestCase {
    func testFixedWrappingColumnsStayFixedWhenWindowWidthChanges() {
        control.wrapsTabs = true
        control.wrappingMinimumCellWidth = 160
        control.wrappingPreferredColumnCount = 6
        addTabCells(7)
        XCTAssertEqual(control.wrappingColumnCount(forWidth: 900), 6)
        XCTAssertEqual(control.wrappingColumnCount(forWidth: 450), 6)
        XCTAssertEqual(control.wrappingRowCount(forWidth: 450), 2)
        control.wrappingPreferredColumnCount = 0
        XCTAssertLessThan(control.wrappingColumnCount(forWidth: 450), 6)
        control.wrappingPreferredColumnCount = 101
        XCTAssertEqual(control.wrappingColumnCount(forWidth: 900), 100)
    }

    #if compiler(>=6.2)
    func testPaletteConfigurationKeepsLastValidSnapshotAndHeight() throws {
        guard #available(macOS 26, *) else { throw XCTSkip("Tahoe style requires macOS 26") }
        let config = PaletteConfiguration.shared
        let previous = try JSONSerialization.data(withJSONObject: config.values)
        defer { config.apply(data: previous) }
        XCTAssertTrue(config.apply(data: Data(##"{"version":1,"height":54,"rowGap":10,"states":{"inactiveSelected":{"foreground":"#123456"}}}"##.utf8)))
        XCTAssertEqual(PSMTahoeTabStyle.paletteRowHeight, 64)
        XCTAssertEqual(config.state(selected: true, active: false)["foreground"] as? String, "#123456")
        XCTAssertFalse(config.apply(data: Data("{".utf8)))
        XCTAssertEqual(PSMTahoeTabStyle.paletteRowHeight, 64)
        XCTAssertFalse(config.apply(data: Data(##"{"version":2}"##.utf8)))
        XCTAssertEqual(PSMTahoeTabStyle.paletteRowHeight, 64)
        XCTAssertTrue(config.apply(data: Data(##"{"height":-10,"rowGap":0}"##.utf8)))
        XCTAssertEqual(PSMTahoeTabStyle.paletteRowHeight, 16)
        config.apply(data: Data(##"{"height":36,"rowGap":6,"paddingTop":2,"paddingBottom":4}"##.utf8))
        XCTAssertEqual(PSMTahoeTabStyle.paletteRowHeight, 48)
    }

    func testPaletteFourStatesAndExplicitTruncation() throws {
        guard #available(macOS 26, *) else { throw XCTSkip("Tahoe style requires macOS 26") }
        let config = PaletteConfiguration.shared
        let previous = try JSONSerialization.data(withJSONObject: config.values)
        defer { config.apply(data: previous) }
        config.apply(data: Data(##"{"truncation":"head","states":{"inactiveSelected":{"foreground":"#000000","background":"#eeeeee","fontSize":23,"fontWeight":"bold"},"inactiveUnselected":{"foreground":"#112233"}}}"##.utf8))
        let style = PSMTahoeTabStyle()
        let attributes = style.paletteTitleAttributes(selected: true)
        XCTAssertEqual((attributes[.font] as? NSFont)?.pointSize, 23)
        let color = try XCTUnwrap((attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.sRGB))
        XCTAssertEqual(color.redComponent, 0)
        XCTAssertEqual(color.greenComponent, 0)
        XCTAssertEqual(color.blueComponent, 0)
        XCTAssertEqual((attributes[.paragraphStyle] as? NSParagraphStyle)?.lineBreakMode, .byTruncatingHead)
        XCTAssertNotEqual(config.state(selected: true, active: false)["foreground"] as? String,
                          config.state(selected: false, active: false)["foreground"] as? String)
    }

    func testPaletteSixColumnsUseButtonGeometryAndHitTargets() throws {
        guard #available(macOS 26, *) else { throw XCTSkip("Tahoe style requires macOS 26") }
        let previous = iTermAdvancedSettingsModel.paletteTabBarStyle()
        let previousHeight = iTermAdvancedSettingsModel.defaultTabBarHeight()
        defer {
            iTermAdvancedSettingsModel.setPaletteTabBarStyle(previous)
            iTermAdvancedSettingsModel.setDefaultTabBarHeight(previousHeight)
        }
        iTermAdvancedSettingsModel.setPaletteTabBarStyle(true)
        iTermAdvancedSettingsModel.setDefaultTabBarHeight(36)
        let style = PSMTahoeLightHighContrastTabStyle()
        style.tabBar = control
        control.style = style
        control.wrapsTabs = true
        control.wrappingPreferredColumnCount = 6
        control.maximumWrappingRows = 10
        control.height = PSMTahoeTabStyle.paletteRowHeight
        control.frame.size.height = control.height * 3
        addTabCells(14)
        let widths = try XCTUnwrap(control.perform(Selector(("wrappingCellWidths")))?.takeUnretainedValue() as? NSArray)
        _ = control.perform(Selector(("_setupCells:")), with: widths)
        let cells = control.cells() as! [PSMTabBarCell]
        XCTAssertEqual(control.wrappingRowCount(forWidth: barWidth), 3)
        XCTAssertEqual(style.intercellSpacing, 6)
        XCTAssertGreaterThanOrEqual(control.height, 42)
        XCTAssertEqual(cells[0].frame.height, control.height - 6)
        XCTAssertEqual(cells[1].frame.minX - cells[0].frame.maxX, 6, accuracy: 0.01)
        XCTAssertEqual(cells[6].frame.minY - cells[0].frame.maxY, 6, accuracy: 0.01)
        for cell in cells {
            let center = NSPoint(x: cell.frame.midX, y: cell.frame.midY)
            XCTAssertTrue((control.cell(for: center, cellFrame: nil) as? PSMTabBarCell) === cell)
        }
        iTermAdvancedSettingsModel.setPaletteTabBarStyle(false)
        XCTAssertFalse(style.usesPaletteButtons)
        XCTAssertEqual(style.intercellSpacing, 2)
    }

    func testPaletteDrawingKeepsBlackWhiteContrastWithoutAKeyWindow() throws {
        guard #available(macOS 26, *) else { throw XCTSkip("Tahoe style requires macOS 26") }
        let previous = iTermAdvancedSettingsModel.paletteTabBarStyle()
        defer { iTermAdvancedSettingsModel.setPaletteTabBarStyle(previous) }
        iTermAdvancedSettingsModel.setPaletteTabBarStyle(true)
        let style = PSMTahoeLightHighContrastTabStyle()
        style.tabBar = control
        control.style = style
        control.wrapsTabs = true
        let cell = PSMTabBarCell(controlView: control)!
        cell.frame = NSRect(x: 6, y: 3, width: 130, height: 36)
        cell.stringValue = "Test ⚪⚫"
        cell.hasCloseButton = false
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 150, pixelsHigh: 42,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        for selected in [false, true] {
            cell.state = selected ? .on : .off
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 150, height: 42).fill()
            style.drawTabCell(cell, highlightAmount: 0)
            context.flushGraphics()
            // Sample away from text, border and rounded corners.
            let fill = try XCTUnwrap(bitmap.colorAt(x: 12, y: 21)?.usingColorSpace(.deviceRGB))
            XCTAssertEqual(fill.redComponent, selected ? 0 : 1, accuracy: 0.01)
            XCTAssertEqual(fill.greenComponent, selected ? 0 : 1, accuracy: 0.01)
            XCTAssertEqual(fill.blueComponent, selected ? 0 : 1, accuracy: 0.01)
            let border = try XCTUnwrap(bitmap.colorAt(x: 7, y: 21)?.usingColorSpace(.deviceRGB))
            XCTAssertEqual(border.redComponent, 0, accuracy: 0.01)
            let attributes = style.paletteTitleAttributes(selected: selected)
            XCTAssertEqual(attributes[.foregroundColor] as? NSColor, selected ? .white : .black)
        }
        control.wrapsTabs = false
        XCTAssertFalse(style.usesPaletteButtons, "The option must not restyle top or side bars")
        control.wrapsTabs = true
        style.orientation = .verticalOrientation
        XCTAssertFalse(style.usesPaletteButtons)
    }

    func testWrappedTahoeClipIncludesSecondRow() throws {
        guard #available(macOS 26, *) else { throw XCTSkip("Tahoe style requires macOS 26") }
        let style = PSMTahoeTabStyle()
        style.tabBar = control
        control.style = style
        control.wrapsTabs = true
        control.height = 36
        control.wrappingMinimumCellWidth = 160
        control.maximumWrappingRows = 10
        let columns = Int(control.wrappingColumnCount(forWidth: barWidth))
        addTabCells(columns + 1)
        control.frame.size.height = 72
        let widths = try XCTUnwrap(control.perform(Selector(("wrappingCellWidths")))?.takeUnretainedValue() as? NSArray)
        _ = control.perform(Selector(("_setupCells:")), with: widths)
        let cells = control.cells() as! [PSMTabBarCell]
        XCTAssertGreaterThan(cells[columns].frame.minY, cells[0].frame.minY,
                             "The style must not reset every row to the top inset")
        let path = try XCTUnwrap(style.accessoryClipPath(forTabBar: control))
        XCTAssertTrue(path.contains(NSPoint(x: 100, y: 10)))
        XCTAssertTrue(path.contains(NSPoint(x: 100, y: 46)), "A first-row-only clip hides all subsequent rows")
        XCTAssertFalse(path.contains(NSPoint(x: 100, y: 32)), "The gap between rows should remain clear")
    }
    #endif

    func testWrappedTabsReserveRowsAndRemainClickableBelowFirstRow() {
        control.wrapsTabs = true
        control.wrappingMinimumCellWidth = 160
        control.maximumWrappingRows = 10
        let columns = Int(control.wrappingColumnCount(forWidth: barWidth))
        addTabCells(columns + 1)
        XCTAssertEqual(control.wrappingRowCount(forWidth: barWidth), 2)
        control.frame.size.height = control.height * 2
        guard let widths = control.perform(Selector(("wrappingCellWidths")))?.takeUnretainedValue() as? NSArray else {
            XCTFail("No wrapping widths")
            return
        }
        _ = control.perform(Selector(("_setupCells:")), with: widths)
        let cells = control.cells() as! [PSMTabBarCell]
        XCTAssertGreaterThan(cells[columns].frame.minY, cells[0].frame.minY)
        XCTAssertFalse(cells[columns].frame.intersects(cells[0].frame))
        let point = NSPoint(x: cells[columns].frame.midX, y: cells[columns].frame.midY)
        XCTAssertTrue((control.cell(for: point, cellFrame: nil) as? PSMTabBarCell) === cells[columns])
    }

    func testWrappingIgnoresCollapsedCellsAndLimitsHeight() {
        control.wrapsTabs = true
        control.wrappingMinimumCellWidth = 160
        control.maximumWrappingRows = 2
        let columns = Int(control.wrappingColumnCount(forWidth: barWidth))
        addTabCells(columns)
        let hidden = PSMTabBarCell(controlView: control)!
        hidden.isCollapsedHidden = true
        control.cells().add(hidden)
        XCTAssertEqual(control.wrappingRowCount(forWidth: barWidth), 1)
        addTabCells(columns * 3)
        XCTAssertEqual(control.wrappingRowCount(forWidth: barWidth), 2)
        XCTAssertEqual(control.wrappingColumnCount(forWidth: 1), 1)
    }

    private let barWidth: CGFloat = 900
    private var control: PSMTabBarControl!

    override func setUp() {
        super.setUp()
        control = PSMTabBarControl(frame: NSRect(x: 0, y: 0, width: barWidth, height: 24))
        // -initWithFrame: assigns _style directly rather than through -setStyle:,
        // which is the only thing that wires the style's back-reference. Without
        // this the style reads `tabBar?.insets.left ?? 0`, the bar's insets never
        // reach the width calculation at all, and every assertion below passes
        // vacuously against a bar that thinks it has the whole 900pt.
        control.style.tabBar = control
        control.cellMinWidth = 60
        // Uneven and optimum sizing are deliberately unrepresented in the
        // minimum, because neither can overflow a bar that fits minimally.
        // Turning them off exercises the expression under test directly.
        control.sizeCellsToFit = false
        control.stretchCellsToFit = false
    }

    override func tearDown() {
        control = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func addTabCells(_ count: Int, pinned: Int = 0) {
        for i in 0..<count {
            let cell = PSMTabBarCell(controlView: control)!
            cell.isPinned = (i < pinned)
            control.cells().add(cell)
        }
    }

    private func addChip(_ groupID: String) {
        let cell = PSMTabBarCell(controlView: control)!
        cell.isTabGroupChip = true
        cell.tabGroupIdentifier = groupID
        control.cells().add(cell)
    }

    private func addGroupedTabCell(_ groupID: String, collapsedHidden: Bool) {
        let cell = PSMTabBarCell(controlView: control)!
        cell.tabGroupIdentifier = groupID
        cell.isCollapsedHidden = collapsedHidden
        control.cells().add(cell)
    }

    private func laidOutWidths(leftInset: CGFloat) -> [CGFloat] {
        control.insets = NSEdgeInsets(top: 0, left: leftInset, bottom: 0, right: 0)
        return (control.cellWidths(forHorizontalArrangementWithOverflow: false) ?? []).map { CGFloat($0.doubleValue) }
    }

    /// The safe direction, and the one the window name's reservation depends on:
    /// at the predicted inset every cell is still laid out, at no less than the
    /// minimum width the bar promises it.
    ///
    /// Note this is a bound on *squeezing*, not on dropping. Past the limit the
    /// bar does not drop a cell -- -computeCellFramesInContainerOfWidth: divides
    /// whatever is left evenly among the cells it has, so they shrink below
    /// cellMinWidth first and are only dropped much later. cellMinWidth is a soft
    /// floor on that path, so "every cell fits" is the wrong thing to assert
    /// against; "every cell fits at its promised width" is the real contract.
    private func assertEveryCellFitsAtItsMinimum(_ what: String,
                                                 file: StaticString = #filePath,
                                                 line: UInt = #line) {
        let expected = control.cells().count
        let maxInset = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)
        XCTAssertGreaterThan(maxInset, 0,
                             "\(what): expected some room to give away",
                             file: file, line: line)

        let widths = laidOutWidths(leftInset: floor(maxInset))
        XCTAssertEqual(widths.count, expected,
                       "\(what): a cell was dropped at the inset we predicted would fit",
                       file: file, line: line)
        // Pinned cells and group chips are laid out at their own fixed widths,
        // so only the ordinary tab cells are held to cellMinWidth.
        let plainWidths = zip(widths, control.cells() as! [PSMTabBarCell])
            .filter { !$0.1.isPinned && !$0.1.isTabGroupChip && !$0.1.isCollapsedHidden }
            .map { $0.0 }
        for width in plainWidths {
            XCTAssertGreaterThanOrEqual(width, CGFloat(control.cellMinWidth) - 0.5,
                                        "\(what): a tab was squeezed under cellMinWidth at the inset we predicted would fit",
                                        file: file, line: line)
        }
    }

    // MARK: - Plain cells

    func testPlainCellsSingle() {
        addTabCells(1)
        assertEveryCellFitsAtItsMinimum("one tab")
    }

    func testPlainCellsSeveral() {
        addTabCells(6)
        assertEveryCellFitsAtItsMinimum("six tabs")
    }

    // The other side of the bound: the prediction should not be leaving usable
    // space on the table. One point past it, the tabs no longer get their
    // minimum. Asserted only for plain cells, where every cell is held to
    // cellMinWidth -- pinned cells and chips have fixed widths of their own and
    // absorb the squeeze differently.
    func testPlainCellsAreSqueezedJustPastTheLimit() {
        addTabCells(6)
        let maxInset = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)
        let widths = laidOutWidths(leftInset: ceil(maxInset) + 1)
        let narrowest = widths.min() ?? 0
        XCTAssertLessThan(narrowest, CGFloat(control.cellMinWidth),
                          "every tab still got its minimum past the predicted limit, so the prediction is too conservative")
    }

    // Intercell spacing is charged per gap, not per cell; a prediction that got
    // that wrong would be off by one gap and drift further with every tab.
    func testPlainCellsSpacingScalesWithCount() {
        addTabCells(2)
        let twoTabs = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)
        addTabCells(1)
        let threeTabs = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)

        let perTabCost = twoTabs - threeTabs
        let expected = CGFloat(control.cellMinWidth) + control.style.intercellSpacing
        XCTAssertEqual(perTabCost, expected, accuracy: 0.01,
                       "each additional tab should cost one cell plus one gap")
    }

    // MARK: - Pinned cells

    func testPinnedAndUnpinnedMix() {
        addTabCells(5, pinned: 2)
        assertEveryCellFitsAtItsMinimum("two pinned, three unpinned")
    }

    func testAllPinned() {
        addTabCells(3, pinned: 3)
        assertEveryCellFitsAtItsMinimum("three pinned")
    }

    // MARK: - Group chips

    func testChipWithExpandedMembers() {
        addChip("group")
        addGroupedTabCell("group", collapsedHidden: false)
        addGroupedTabCell("group", collapsedHidden: false)
        addTabCells(2)
        assertEveryCellFitsAtItsMinimum("chip with two visible members")
    }

    // The case a raw tab count gets wrong: collapsed members occupy no width and
    // no spacing, so counting them overstates what the tabs need and the name
    // gives up space it could have had.
    func testCollapsedMembersDoNotInflateTheMinimum() {
        addChip("group")
        addGroupedTabCell("group", collapsedHidden: true)
        addGroupedTabCell("group", collapsedHidden: true)
        addTabCells(2)
        let withCollapsed = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)

        addGroupedTabCell("group", collapsedHidden: true)
        let withOneMoreCollapsed = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)

        XCTAssertEqual(withCollapsed, withOneMoreCollapsed, accuracy: 0.01,
                       "a hidden collapsed member should cost the bar nothing")
    }

    // MARK: - What a decoration may take

    // -maximumLeftInsetLeavingTabsUsableForWidth: asks the other question: how
    // much may something painted over the strip take before the bar stops being
    // usable. Fitting every cell minimally is the wrong bar for that when the
    // bar scrolls, because the cells past the first are never laid out in the
    // space the decoration would surrender.

    private func withScrollableTabBar(_ enabled: Bool, _ body: () -> Void) {
        let saved = iTermPreferences.bool(forKey: kPreferenceKeyScrollableSideTabBar)
        iTermPreferences.setBool(enabled, forKey: kPreferenceKeyScrollableSideTabBar)
        defer { iTermPreferences.setBool(saved, forKey: kPreferenceKeyScrollableSideTabBar) }
        body()
    }

    func testScrollableBarDoesNotChargeForTabsBeyondTheFirst() {
        withScrollableTabBar(true) {
            addTabCells(3)
            let threeTabs = control.maximumLeftInsetLeavingTabsUsable(forWidth: barWidth)
            addTabCells(5)
            let eightTabs = control.maximumLeftInsetLeavingTabsUsable(forWidth: barWidth)

            XCTAssertEqual(threeTabs, eightTabs, accuracy: 0.01,
                           "a scrollable bar scrolls to its extra tabs, so they should cost a decoration nothing")
        }
    }

    func testNonScrollableBarChargesForEveryTab() {
        withScrollableTabBar(false) {
            addTabCells(3)
            let threeTabs = control.maximumLeftInsetLeavingTabsUsable(forWidth: barWidth)
            addTabCells(5)
            let eightTabs = control.maximumLeftInsetLeavingTabsUsable(forWidth: barWidth)

            XCTAssertEqual(threeTabs - eightTabs,
                           5 * (CGFloat(control.cellMinWidth) + control.style.intercellSpacing),
                           accuracy: 0.01,
                           "a bar that cannot scroll needs room for every tab")
            XCTAssertEqual(eightTabs,
                           control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth),
                           accuracy: 0.01,
                           "with no scrolling the two questions have the same answer")
        }
    }

    // The scrollable answer is a relaxation, never a tightening: a decoration
    // can only gain room by the bar being scrollable.
    func testScrollableBarIsNeverStricterThanFittingEveryCell() {
        for count in [1, 2, 6] {
            control.cells().removeAllObjects()
            addTabCells(count)
            let fittingAll = control.maximumLeftInsetFittingAllCellsMinimally(forWidth: barWidth)
            withScrollableTabBar(true) {
                XCTAssertGreaterThanOrEqual(control.maximumLeftInsetLeavingTabsUsable(forWidth: barWidth),
                                            fittingAll - 0.01,
                                            "\(count) tabs: scrolling should never leave a decoration less room")
            }
        }
    }
}
