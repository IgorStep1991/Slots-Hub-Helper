import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "background_big_bass_slots" asset catalog image resource.
    static let backgroundBigBassSlots = DeveloperToolsSupport.ImageResource(name: "background_big_bass_slots", bundle: resourceBundle)

    /// The "background_bonanza_slots" asset catalog image resource.
    static let backgroundBonanzaSlots = DeveloperToolsSupport.ImageResource(name: "background_bonanza_slots", bundle: resourceBundle)

    /// The "background_joker_slots" asset catalog image resource.
    static let backgroundJokerSlots = DeveloperToolsSupport.ImageResource(name: "background_joker_slots", bundle: resourceBundle)

    /// The "history_delete_action_icon" asset catalog image resource.
    static let historyDeleteActionIcon = DeveloperToolsSupport.ImageResource(name: "history_delete_action_icon", bundle: resourceBundle)

    /// The "profile_avatar_ice_tracker" asset catalog image resource.
    static let profileAvatarIceTracker = DeveloperToolsSupport.ImageResource(name: "profile_avatar_ice_tracker", bundle: resourceBundle)

    /// The "universe_big_bass_slots" asset catalog image resource.
    static let universeBigBassSlots = DeveloperToolsSupport.ImageResource(name: "universe_big_bass_slots", bundle: resourceBundle)

    /// The "universe_bonanza_slots" asset catalog image resource.
    static let universeBonanzaSlots = DeveloperToolsSupport.ImageResource(name: "universe_bonanza_slots", bundle: resourceBundle)

    /// The "universe_joker_slots" asset catalog image resource.
    static let universeJokerSlots = DeveloperToolsSupport.ImageResource(name: "universe_joker_slots", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "background_big_bass_slots" asset catalog image.
    static var backgroundBigBassSlots: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .backgroundBigBassSlots)
#else
        .init()
#endif
    }

    /// The "background_bonanza_slots" asset catalog image.
    static var backgroundBonanzaSlots: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .backgroundBonanzaSlots)
#else
        .init()
#endif
    }

    /// The "background_joker_slots" asset catalog image.
    static var backgroundJokerSlots: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .backgroundJokerSlots)
#else
        .init()
#endif
    }

    /// The "history_delete_action_icon" asset catalog image.
    static var historyDeleteActionIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .historyDeleteActionIcon)
#else
        .init()
#endif
    }

    /// The "profile_avatar_ice_tracker" asset catalog image.
    static var profileAvatarIceTracker: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .profileAvatarIceTracker)
#else
        .init()
#endif
    }

    /// The "universe_big_bass_slots" asset catalog image.
    static var universeBigBassSlots: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .universeBigBassSlots)
#else
        .init()
#endif
    }

    /// The "universe_bonanza_slots" asset catalog image.
    static var universeBonanzaSlots: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .universeBonanzaSlots)
#else
        .init()
#endif
    }

    /// The "universe_joker_slots" asset catalog image.
    static var universeJokerSlots: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .universeJokerSlots)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "background_big_bass_slots" asset catalog image.
    static var backgroundBigBassSlots: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .backgroundBigBassSlots)
#else
        .init()
#endif
    }

    /// The "background_bonanza_slots" asset catalog image.
    static var backgroundBonanzaSlots: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .backgroundBonanzaSlots)
#else
        .init()
#endif
    }

    /// The "background_joker_slots" asset catalog image.
    static var backgroundJokerSlots: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .backgroundJokerSlots)
#else
        .init()
#endif
    }

    /// The "history_delete_action_icon" asset catalog image.
    static var historyDeleteActionIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .historyDeleteActionIcon)
#else
        .init()
#endif
    }

    /// The "profile_avatar_ice_tracker" asset catalog image.
    static var profileAvatarIceTracker: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .profileAvatarIceTracker)
#else
        .init()
#endif
    }

    /// The "universe_big_bass_slots" asset catalog image.
    static var universeBigBassSlots: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .universeBigBassSlots)
#else
        .init()
#endif
    }

    /// The "universe_bonanza_slots" asset catalog image.
    static var universeBonanzaSlots: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .universeBonanzaSlots)
#else
        .init()
#endif
    }

    /// The "universe_joker_slots" asset catalog image.
    static var universeJokerSlots: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .universeJokerSlots)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

