//
//  PreferencesSearchTests.swift
//  ModernTests
//
//  Ported from iTerm2XCTests/iTermPreferencesSearchTests.m. Covers document tokenization and
//  querying in iTermPreferencesSearchEngine.
//

import XCTest
import Cocoa
@testable import iTerm2SharedARC

final class PortraitSettingsLayoutTests: XCTestCase {
    func testControlsReflowWithoutLosingIdentityAndRestoreDesktopFrames() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 200))
        let first = NSTextField(labelWithString: "First setting")
        first.frame = NSRect(x: 20, y: 140, width: 450, height: 24)
        let second = NSTextField(string: "Editable value")
        second.frame = NSRect(x: 650, y: 140, width: 450, height: 24)
        content.addSubview(first)
        content.addSubview(second)
        let original = second.frame
        let host = iTermPortraitSettingsHost(content: content)
        host.frame = NSRect(x: 0, y: 0, width: 760, height: 120)
        host.layoutSubtreeIfNeeded()
        host.layout()
        XCTAssertTrue(second.superview === content)
        XCTAssertLessThanOrEqual(second.frame.maxX, content.bounds.width)
        XCTAssertNotEqual(first.frame.minY, second.frame.minY)
        XCTAssertLessThanOrEqual(content.bounds.height - max(first.frame.maxY, second.frame.maxY), 20)
        XCTAssertEqual(second.stringValue, "Editable value")
        host.frame.size.height = 300
        host.layout()
        XCTAssertLessThanOrEqual(content.bounds.height - max(first.frame.maxY, second.frame.maxY), 20)
        host.frame.size.width = 1200
        host.layout()
        XCTAssertEqual(second.frame, original)
    }

    func testWideSettingsSheetReflowsAndRetainsItsControls() {
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 800), styleMask: [.titled], backing: .buffered, defer: true)
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 400), styleMask: [.titled], backing: .buffered, defer: true)
        let field = NSTextField(string: "Sample rule")
        field.frame = NSRect(x: 600, y: 200, width: 280, height: 24)
        sheet.contentView?.addSubview(field)
        iTermPortraitSettingsCoordinator.adaptSheet(sheet, parent: parent)
        sheet.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(sheet.frame.width, 800)
        XCTAssertTrue(sheet.contentView is iTermPortraitSettingsHost)
        XCTAssertTrue(field.window === sheet)
        XCTAssertLessThanOrEqual(field.frame.maxX, field.superview!.bounds.width)
        XCTAssertEqual(field.stringValue, "Sample rule")
    }

    func testAllSettingsPanelsFitAn800PointWindow() throws {
        let previous = iTermAdvancedSettingsModel.portraitSettingsLayout()
        iTermAdvancedSettingsModel.setPortraitSettingsLayout(true)
        defer { iTermAdvancedSettingsModel.setPortraitSettingsLayout(previous) }
        let panel = PreferencePanel.sharedInstance()
        let window = try XCTUnwrap(panel.window)
        defer { window.close() }
        window.setFrame(NSRect(x: 0, y: 0, width: 800, height: 1000), display: false)
        let root = try XCTUnwrap(panel.value(forKey: "_tabView") as? NSTabView)
        var count = 0
        func check(_ view: NSView) {
            if view.isHidden { return }
            if let box = view as? NSBox, let content = box.contentView { check(content); return }
            for child in view.subviews {
                if child.isHidden { continue }
                XCTAssertGreaterThanOrEqual(child.frame.minX, -1, "\(type(of: child))")
                XCTAssertLessThanOrEqual(child.frame.maxX, view.bounds.width + 1, "\(type(of: child)): \(child.frame) in \(view.bounds)")
                if !(child is NSControl) && !(child is NSScrollView) && !(child is NSTabView) { check(child) }
            }
        }
        func visit(_ view: NSView) {
            if let tabs = view as? NSTabView {
                for item in tabs.tabViewItems {
                    tabs.selectTabViewItem(item)
                    window.contentView?.layoutSubtreeIfNeeded()
                    if let content = item.view { visit(content) }
                }
                return
            }
            if let host = view as? iTermPortraitSettingsHost {
                count += 1
                host.layoutSubtreeIfNeeded()
                host.layout()
                if host.window === window, let content = window.contentView {
                    let visibleFrame = host.convert(host.bounds, to: content)
                    XCTAssertGreaterThanOrEqual(visibleFrame.minX, -1)
                    XCTAssertLessThanOrEqual(visibleFrame.maxX, content.bounds.width + 1,
                                            "A scroll container must fit inside the window")
                }
                check(host.originalView)
                return
            }
            for child in view.subviews { visit(child) }
        }
        visit(root)
        let profiles = try XCTUnwrap(panel.value(forKey: "_profilesViewController") as? ProfilePreferencesViewController)
        profiles.layoutForPortraitWindow()
        let list = try XCTUnwrap(profiles.value(forKey: "_profilesListView") as? NSView)
        let details = try XCTUnwrap(profiles.value(forKey: "_tabViewWrapperView") as? NSView)
        XCTAssertGreaterThanOrEqual(list.frame.minY, details.frame.maxY)
        XCTAssertGreaterThan(count, 15, "Exercise the real global and profile sub-panels")
        XCTAssertEqual(window.frame.width, 800, accuracy: 1)
        panel.showProfilesTabView(nil)
        let profileTabs = try XCTUnwrap(profiles.value(forKey: "_tabView") as? NSTabView)
        let textTab = try XCTUnwrap(profiles.value(forKey: "_textTab") as? NSTabViewItem)
        profileTabs.selectTabViewItem(textTab)
        profiles.layoutForPortraitWindow()
        window.contentView?.layoutSubtreeIfNeeded()
        let content = try XCTUnwrap(window.contentView)
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/native-screenshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("portrait-settings-800.png"))
    }
}

final class PreferencesSearchTests: XCTestCase {
    private var engine: iTermPreferencesSearchEngine!

    override func setUp() {
        super.setUp()
        engine = iTermPreferencesSearchEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    private func document(_ displayName: String,
                          identifier: String,
                          keywordPhrases: [String] = []) -> iTermPreferencesSearchDocument {
        return iTermPreferencesSearchDocument(displayName: displayName,
                                              identifier: identifier,
                                              keywordPhrases: keywordPhrases,
                                              profileTypes: .all)
    }

    private func index(_ documents: iTermPreferencesSearchDocument...) {
        for document in documents {
            engine.addDocument(toIndex: document)
        }
    }

    private func matches(_ query: String) -> [iTermPreferencesSearchDocument] {
        return engine.documents(matchingQuery: query, allowedProfileTypes: .all)
    }

    private func identifiersMatching(_ query: String) -> Set<String> {
        return Set(matches(query).map { $0.identifier })
    }

    func testDocumentTokenization() {
        let doc = document("foo bar",
                           identifier: "id1",
                           keywordPhrases: ["lorem ipsum dolor", "sit amet"])
        let expected = ["foo", "bar", "lorem", "ipsum", "dolor", "sit", "amet"].sorted()
        XCTAssertEqual(doc.allKeywords.sorted(), expected)
    }

    func testSimple() {
        let doc1 = document("1", identifier: "id1")
        let doc2 = document("2", identifier: "id2")
        index(doc1, doc2)

        XCTAssertEqual(matches("1"), [doc1])
    }

    func testMultiword() {
        index(document("foo bar", identifier: "id1"),
              document("bar baz foo", identifier: "id2"),
              document("baz foo", identifier: "id3"))

        XCTAssertEqual(identifiersMatching("bar foo"), ["id1", "id2"])
    }

    func testPrefixMatches_SingleLetterMatchesEveryWordStartingWithIt() {
        index(document("aa ab ba", identifier: "id1"),
              document("a", identifier: "id2"),
              document("abc", identifier: "id3"))

        XCTAssertEqual(identifiersMatching("a"), ["id1", "id2", "id3"])
    }

    func testPrefixMatches_EveryQueryTokenMustMatch() {
        index(document("aa ab ba", identifier: "id1"),
              document("a", identifier: "id2"),
              document("abc", identifier: "id3"))

        XCTAssertEqual(identifiersMatching("a b"), ["id1"])
    }

    func testPrefixMatches_LongerPrefix() {
        index(document("aa ab ba", identifier: "id1"),
              document("a", identifier: "id2"),
              document("abc", identifier: "id3"))

        XCTAssertEqual(identifiersMatching("ab"), ["id1", "id3"])
    }

    func testDocumentWithKey() {
        let doc1 = document("one", identifier: "id1")
        let doc2 = document("two", identifier: "id2")
        index(doc1, doc2)

        XCTAssertEqual(engine.document(withKey: "id2"), doc2)
        XCTAssertNil(engine.document(withKey: "id3"))
    }
}
