//
//  StatusBarManager.swift
//  LaVieKey
//
//  Manager for Status Bar with Glass Design Popover
//

import SwiftUI
import Cocoa
import Combine

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverCloseObserver: NSObjectProtocol?
    /// When the popover last closed — used to tell "click the icon to close it"
    /// apart from "click the icon to open it" (see togglePopover).
    private var lastPopoverCloseAt: Date = .distantPast
    let viewModel: StatusBarViewModel
    private var menuBarIconStyle: MenuBarIconStyle = .x
    weak var debugWindowController: DebugWindowController?
    var onCheckForUpdates: (() -> Void)?
    
    init(keyboardHandler: KeyboardEventHandler?, eventTapManager: EventTapManager?) {
        self.viewModel = StatusBarViewModel(
            keyboardHandler: keyboardHandler,
            eventTapManager: eventTapManager
        )
        // Load icon style from preferences
        self.menuBarIconStyle = SharedSettings.shared.loadPreferences().menuBarIconStyle
    }
    
    deinit {
        if let observer = popoverCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func log(_ message: String) {
        debugWindowController?.logEvent(message)
    }
    
    func setupStatusBar() {
        // Connect viewModel's debug callback to our debugWindowController
        viewModel.debugLogCallback = { [weak self] message in
            self?.debugWindowController?.logEvent(message)
        }
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else {
            log("Failed to create status bar button")
            return
        }
        
        // Set initial icon
        updateStatusIcon()
        
        // Handle click to toggle popover (no NSMenu)
        button.action = #selector(togglePopover)
        button.target = self
        
        // Create popover with glass design
        setupPopover()
        
        // Observe changes to update icon
        viewModel.$isVietnameseEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        viewModel.$isJapaneseEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
        
        viewModel.$currentInputMethod
            .receive(on: DispatchQueue.main)
            .sink { [weak self] method in
                self?.log("📋 currentInputMethod changed to \(method.displayName)")
            }
            .store(in: &cancellables)
        
        viewModel.$currentCodeTable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] table in
                self?.log("📋 currentCodeTable changed to \(table.displayName)")
            }
            .store(in: &cancellables)

        viewModel.$debugModeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.log("🐛 Debug mode changed to \(enabled)")
            }
            .store(in: &cancellables)

        log("Status bar setup complete (glass popover)")
    }
    
    // MARK: - Popover Setup
    
    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient  // Close when clicking outside
        popover.animates = true
        
        // Create SwiftUI content view
        let contentView = StatusBarPopoverView(
            viewModel: viewModel,
            onCheckForUpdates: { [weak self] in
                self?.onCheckForUpdates?()
            },
            onDismiss: { [weak self] in
                self?.closePopover()
            }
        )
        
        // Use NSHostingController to host SwiftUI in the popover
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
        
        // Apply glass/vibrancy effect to the popover's content view
        // This creates the frosted glass appearance like macOS system menus
        popover.contentViewController?.view.wantsLayer = true

        // .transient already dismisses on any interaction outside the popover, so
        // this only records *when* that happened.
        popoverCloseObserver = NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification, object: popover, queue: .main
        ) { [weak self] _ in
            self?.lastPopoverCloseAt = Date()
            self?.log("Popover closed")
        }

        self.popover = popover
    }
    
    // MARK: - Popover Toggle
    
    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            closePopover()
        } else {
            // The click that dismissed a .transient popover must not reopen it:
            // AppKit closes on mouse-down, this action runs on mouse-up, so
            // isShown is already false by the time we get here.
            guard Date().timeIntervalSince(lastPopoverCloseAt) > 0.25 else { return }

            // Recreate content view to ensure fresh state
            let contentView = StatusBarPopoverView(
                viewModel: viewModel,
                onCheckForUpdates: { [weak self] in
                    self?.onCheckForUpdates?()
                },
                onDismiss: { [weak self] in
                    self?.closePopover()
                }
            )
            let hostingController = NSHostingController(rootView: contentView)
            popover.contentViewController = hostingController
            
            // Activate app so popover receives keyboard focus
            NSApp.activate(ignoringOtherApps: true)
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Ensure popover window becomes key window for focus
            popover.contentViewController?.view.window?.makeKey()
            log("Popover shown")
        }
    }

    /// Dismissal is handled by the popover's own `.transient` behavior.
    ///
    /// There used to be an `NSEvent.addGlobalMonitorForEvents` here that closed
    /// the popover on any mouse-down. A global monitor sees every click that is
    /// *not* delivered to the active app — so the moment LaVieKey was not the
    /// active app, the click on the status item (hosted by ControlCenter) and the
    /// clicks inside the popover itself both reached the monitor and shut the
    /// popover before any button could fire. Nothing in the dropdown could be
    /// clicked. `.transient` does the same job from inside AppKit, correctly.
    private func closePopover() {
        popover?.performClose(nil)
    }

    // MARK: - Status Icon
    
    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        
        if menuBarIconStyle == .emoji {
            // Emoji flags render in natural color, no template image needed
            let iconText = viewModel.isJapaneseEnabled
                ? "🇯🇵"
                : (viewModel.isVietnameseEnabled ? "🇻🇳" : "🇬🇧")
            button.image = nil
            button.imagePosition = .noImage
            button.title = ""
            button.attributedTitle = NSAttributedString(
                string: iconText,
                attributes: [.font: NSFont.systemFont(ofSize: 16)]
            )
            return
        }
        
        // Letter style (LV brand or V) — render as template image with border.
        // Japanese mode shows あ regardless of letter style.
        let iconText: String
        if viewModel.isJapaneseEnabled {
            iconText = "あ"
        } else if menuBarIconStyle == .x {
            iconText = viewModel.isVietnameseEnabled ? "LV" : "E"
        } else {
            iconText = viewModel.isVietnameseEnabled ? "V" : "E"
        }

        // Two-letter "LV" needs a smaller font to fit the 20×20 bordered box
        let fontSize: CGFloat = iconText.count > 1 ? 9.5 : 14
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw border around the icon
            let borderRect = NSRect(x: 1.5, y: 1.5, width: size.width - 3, height: size.height - 3)
            let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 2.5, yRadius: 2.5)
            NSColor.white.setStroke()
            borderPath.lineWidth = 1.0
            borderPath.stroke()
            
            // Draw text centered
            let textSize = (iconText as NSString).size(withAttributes: attributes)
            let textRect = NSRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (iconText as NSString).draw(in: textRect, withAttributes: attributes)
            return true
        }
        
        image.isTemplate = true
        button.attributedTitle = NSAttributedString(string: "")
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = image
    }
    
    func updateHotkeyDisplay(_ hotkey: Hotkey) {
        viewModel.updateHotkeyDisplay(hotkey)
    }
    
    func updateMenuBarIconStyle(_ style: MenuBarIconStyle) {
        menuBarIconStyle = style
        updateStatusIcon()
        log("🎨 Menu bar icon style updated to: \(style.rawValue)")
    }
    
    private var cancellables = Set<AnyCancellable>()
}
