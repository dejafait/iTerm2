//
//  iTermPreferencesBaseViewController.swift
//  iTerm2
//
//  Created by George Nachman on 6/21/25.
//


import Cocoa

extension NSView {
    // closure returns whether it should recurse down a subview.
    func walk(_ closure: (Either<NSView, NSTabView>) -> (Bool)) {
        if let tabView = self as? NSTabView {
            if closure(.right(tabView)) {
                for item in tabView.tabViewItems {
                    item.view?.walk(closure)
                }
            }
        }
        if let scrollView = self as? NSScrollView {
            // Avoid the clipview and scrollers
            if closure(.left(scrollView)) {
                scrollView.documentView?.walk(closure)
            }
            return
        }
        for subview in subviews {
            if closure(.left(subview)) {
                subview.walk(closure)
            }
        }
    }
}

@objc
extension iTermPreferencesBaseViewController {
    // Returns whether the tab view item can remain because it has visible subviews.
    @objc(setVisibilityForTerminalEnclosures:browserEnclosures:hiddenModeEnclosures:sharedProfilesEnclosures:tabViewItem:)
    func setVisibility(
        forTerminalEnclosures terminal: Bool,
        browserEnclosures browser: Bool,
        hiddenModeEnclosures hidden: Bool,
        sharedProfilesEnclosures sharedProfiles: Bool,
        tabViewItem: NSTabViewItem) -> Bool {
            guard let view = tabViewItem.view else {
                return false
            }
            return view.setVisibility(forTerminalEnclosures: terminal,
                                      browserEnclosures: browser,
                                      hiddenModeEnclosures: hidden,
                                      sharedProfilesEnclosures: sharedProfiles,
                                      stateStorage: internalState,
                                      shrinkage: nil)
        }
}

// MARK: - Optional portrait settings layout

// Reflow the original controls rather than duplicating preference models or
// bindings. Desktop geometry and constraints are restored when widened again.
private final class PortraitFormNode {
    let view: NSView
    let original: NSRect
    let mask: NSView.AutoresizingMask
    let translates: Bool
    let constraints: [NSLayoutConstraint]
    let children: [PortraitFormNode]
    private let textAlignment: NSTextAlignment?
    private let wraps: Bool?
    private let singleLine: Bool?

    init(_ view: NSView) {
        self.view = view
        original = view.frame
        mask = view.autoresizingMask
        translates = view.translatesAutoresizingMaskIntoConstraints
        constraints = view.constraints
        if let text = view as? NSTextField {
            textAlignment = text.alignment
            wraps = text.cell?.wraps
            singleLine = text.cell?.usesSingleLineMode
        } else {
            textAlignment = nil; wraps = nil; singleLine = nil
        }
        if let box = view as? NSBox, let content = box.contentView {
            children = [PortraitFormNode(content)]
        } else if view is NSControl || view is NSScrollView || view is NSTabView {
            children = []
        } else {
            children = view.subviews.map(PortraitFormNode.init)
        }
    }

    func restore() {
        NSLayoutConstraint.deactivate(view.constraints)
        view.translatesAutoresizingMaskIntoConstraints = translates
        view.autoresizingMask = mask
        view.frame = original
        if let text = view as? NSTextField {
            if let textAlignment { text.alignment = textAlignment }
            if let wraps { text.cell?.wraps = wraps }
            if let singleLine { text.cell?.usesSingleLineMode = singleLine }
        }
        children.forEach { $0.restore() }
        NSLayoutConstraint.activate(constraints)
    }

    @discardableResult func reflow(width: CGFloat) -> CGFloat {
        let available = max(80, width)
        NSLayoutConstraint.deactivate(view.constraints)
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = []
        if let box = view as? NSBox, let child = children.first {
            let height = child.reflow(width: max(80, available - 24)) + 36
            view.setFrameSize(NSSize(width: available, height: height))
            child.view.frame.origin = NSPoint(x: 12, y: 12)
            box.needsDisplay = true
            return height
        }
        if children.isEmpty {
            let width = min(original.width, available)
            var height = original.height
            if let text = view as? NSTextField, !text.isEditable {
                text.alignment = .left
                text.cell?.wraps = true
                text.cell?.usesSingleLineMode = false
                let font = text.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                height = max(height, ceil((text.stringValue as NSString).boundingRect(
                    with: NSSize(width: max(1, width - 4), height: 10_000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font]).height) + 4)
            }
            view.setFrameSize(NSSize(width: width, height: height))
            if let scroll = view as? NSScrollView {
                scroll.hasHorizontalScroller = false
                if let table = scroll.documentView as? NSTableView {
                    table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
                    table.sizeLastColumnToFit()
                }
            }
            return height
        }

        func top(_ node: PortraitFormNode) -> CGFloat {
            view.isFlipped ? node.original.minY : original.height - node.original.maxY
        }
        let ordered = children.sorted {
            if abs(top($0) - top($1)) > 6 { return top($0) < top($1) }
            return $0.original.minX < $1.original.minX
        }
        var placements: [(PortraitFormNode, CGFloat, CGFloat, CGFloat)] = []
        var x: CGFloat = 12
        var y: CGFloat = 12
        var rowHeight: CGFloat = 0
        var previousTop: CGFloat?
        for child in ordered {
            let rowTop = top(child)
            let desiredWidth = min(max(20, child.original.width), available - 24)
            if let previousTop, abs(rowTop - previousTop) > 6 || x + desiredWidth > available - 12 {
                y += rowHeight + 10
                x = 12
                rowHeight = 0
            }
            let height = child.reflow(width: desiredWidth)
            placements.append((child, x, y, height))
            x += child.view.frame.width + 8
            rowHeight = max(rowHeight, height)
            previousTop = rowTop
        }
        let height = y + rowHeight + 12
        view.setFrameSize(NSSize(width: available, height: height))
        for (child, x, y, childHeight) in placements {
            child.view.frame.origin = NSPoint(x: x, y: view.isFlipped ? y : height - y - childHeight)
        }
        return height
    }
}

@objc final class iTermPortraitSettingsHost: NSScrollView {
    @objc let originalView: NSView
    private let form: PortraitFormNode
    private var frameObserver: NSObjectProtocol?
    private var previousWidth: CGFloat = 0
    private var previousHeight: CGFloat = 0
    private var portrait = false
    private var layingOut = false

    @objc init(content: NSView) {
        originalView = content
        form = PortraitFormNode(content)
        super.init(frame: content.frame)
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        autoresizingMask = [.width, .height]
        documentView = content
        content.postsFrameChangedNotifications = true
        frameObserver = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: content, queue: .main) { [weak self] _ in self?.needsLayout = true }
    }
    deinit { if let frameObserver { NotificationCenter.default.removeObserver(frameObserver) } }
    required init?(coder: NSCoder) { return nil }

    override func layout() {
        super.layout()
        guard !layingOut else { return }
        layingOut = true
        defer { layingOut = false }
        let narrow = (window?.frame.width ?? frame.width) <= 900
        if narrow, let content = window?.contentView {
            var ancestor = superview
            while let current = ancestor, current !== content {
                if current is NSTabView {
                    let x = current.convert(current.bounds, to: content).minX
                    let width = max(100, content.bounds.width - x - 10)
                    if current.frame.width > width { current.setFrameSize(NSSize(width: width, height: current.frame.height)) }
                }
                ancestor = current.superview
            }
            let x = convert(bounds, to: content).minX
            let width = max(100, content.bounds.width - x - 10)
            if frame.width > width { setFrameSize(NSSize(width: width, height: frame.height)) }
        }
        let width = max(100, contentSize.width)
        guard narrow != portrait || abs(width - previousWidth) > 0.5 || abs(contentSize.height - previousHeight) > 0.5 || (narrow && abs(originalView.frame.width - width) > 0.5) else { return }
        previousWidth = width
        previousHeight = contentSize.height
        portrait = narrow
        if narrow {
            let height = form.reflow(width: width)
            if height < contentSize.height {
                let extra = contentSize.height - height
                originalView.setFrameSize(NSSize(width: width, height: contentSize.height))
                if !originalView.isFlipped {
                    for child in originalView.subviews { child.frame.origin.y += extra }
                }
            }
        } else {
            form.restore()
        }
        let y = originalView.isFlipped ? 0 : max(0, originalView.frame.height - contentSize.height)
        contentView.scroll(to: NSPoint(x: 0, y: y))
        reflectScrolledClipView(contentView)
    }
}

@objc final class iTermPortraitSettingsCoordinator: NSObject {
    private weak var window: NSWindow?
    private weak var tabs: NSTabView?
    private var observer: NSObjectProtocol?
    private var sheetObserver: NSObjectProtocol?
    private var originalToolbarMode: NSToolbar.DisplayMode = .iconAndLabel
    private var tabGeometry: [(NSTabView, NSRect, CGFloat)] = []
    @objc var layoutHandler: (() -> Void)?

    @objc init(window: NSWindow, tabView: NSTabView) {
        self.window = window
        tabs = tabView
        super.init()
        originalToolbarMode = window.toolbar?.displayMode ?? .iconAndLabel
        func collect(_ view: NSView) {
            if let tabs = view as? NSTabView {
                tabGeometry.append((tabs, tabs.frame, tabs.superview?.bounds.width ?? tabs.frame.width))
                for item in tabs.tabViewItems { if let child = item.view { collect(child) } }
            } else { view.subviews.forEach(collect) }
        }
        collect(tabView)
        Self.install(in: tabView)
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 640, height: 420)
        if let screen = window.screen, screen.visibleFrame.width <= 1000 {
            var frame = window.frame
            frame.size.width = min(800, screen.visibleFrame.width - 24)
            frame.size.height = min(1000, screen.visibleFrame.height - 80)
            frame.origin.x = max(screen.visibleFrame.minX, min(frame.minX, screen.visibleFrame.maxX - frame.width))
            frame.origin.y = max(screen.visibleFrame.minY, min(frame.minY, screen.visibleFrame.maxY - frame.height))
            window.setFrame(frame, display: false)
        }
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification,
            object: window, queue: .main) { [weak self] _ in self?.update() }
        sheetObserver = NotificationCenter.default.addObserver(forName: NSWindow.willBeginSheetNotification,
            object: nil, queue: .main) { [weak self] notification in
                guard let self, let owner = self.window, let parent = notification.object as? NSWindow else { return }
                var ancestor: NSWindow? = parent
                while let current = ancestor, current !== owner { ancestor = current.sheetParent }
                guard ancestor === owner else { return }
                DispatchQueue.main.async { [weak parent] in
                    if let parent, let sheet = parent.attachedSheet { Self.adaptSheet(sheet, parent: parent) }
                }
            }
        update()
    }
    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let sheetObserver { NotificationCenter.default.removeObserver(sheetObserver) }
    }

    @objc static func adaptSheet(_ sheet: NSWindow, parent: NSWindow) {
        guard !(sheet is NSSavePanel), parent.frame.width <= 900,
              let content = sheet.contentView, !(content is iTermPortraitSettingsHost),
              sheet.frame.width > min(800, parent.frame.width) else { return }
        sheet.contentView = iTermPortraitSettingsHost(content: content)
        sheet.styleMask.insert(.resizable)
        sheet.minSize = NSSize(width: 560, height: 240)
        var frame = sheet.frame
        frame.size.width = min(800, parent.frame.width)
        if let screen = parent.screen { frame.size.height = min(frame.height, screen.visibleFrame.height - 80) }
        sheet.setFrame(frame, display: false)
        sheet.contentView?.layoutSubtreeIfNeeded()
    }

    @objc func update() {
        guard let window else { return }
        window.toolbar?.displayMode = window.frame.width <= 900 ? .iconOnly : originalToolbarMode
        if let content = window.contentView {
            for (tabs, original, parentWidth) in tabGeometry {
                if window.frame.width <= 900, tabs.window === window {
                    let x = tabs.convert(tabs.bounds, to: content).minX
                    tabs.setFrameSize(NSSize(width: max(100, content.bounds.width - x - 10), height: tabs.frame.height))
                } else if window.frame.width > 900 {
                    var frame = tabs.frame
                    frame.size.width = original.width
                    if tabs.autoresizingMask.contains(.width) { frame.size.width += (tabs.superview?.bounds.width ?? parentWidth) - parentWidth }
                    tabs.frame = frame
                }
            }
        }
        layoutHandler?()
        tabs?.needsLayout = true
    }

    private static func containsTabView(_ view: NSView) -> Bool {
        view is NSTabView || view.subviews.contains { containsTabView($0) }
    }
    private static func install(in tabView: NSTabView) {
        for item in tabView.tabViewItems {
            guard let view = item.view, !(view is iTermPortraitSettingsHost) else { continue }
            if containsTabView(view) {
                view.walk { element in
                    if case let .right(tabs) = element { install(in: tabs); return false }
                    return true
                }
            } else {
                item.view = iTermPortraitSettingsHost(content: view)
            }
        }
    }

    @objc static func originalView(_ view: NSView) -> NSView {
        (view as? iTermPortraitSettingsHost)?.originalView ?? view
    }
    @objc static func adjustedFrame(_ proposed: NSRect, window: NSWindow) -> NSRect {
        guard iTermAdvancedSettingsModel.portraitSettingsLayout() else { return proposed }
        var result = proposed
        let visible = window.screen?.visibleFrame ?? proposed
        if window.frame.width <= 900 {
            result.size = window.frame.size
        }
        result.size.width = max(640, min(result.width, visible.width - 24))
        result.size.height = max(420, min(result.height, visible.height - 60))
        result.origin.x = max(visible.minX, min(result.minX, visible.maxX - result.width))
        result.origin.y = max(visible.minY, min(proposed.maxY - result.height, visible.maxY - result.height))
        return result
    }
}
