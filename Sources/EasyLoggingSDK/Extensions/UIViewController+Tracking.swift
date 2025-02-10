import UIKit
import ObjectiveC

extension UIViewController {
    private static var hasSwizzled = false
    private static let swizzlingLock = NSLock()
    
    /// Swizzle viewWillAppear and viewDidAppear methods for automatic screen time tracking
    static func setupScreenTimeTracking() {
        swizzlingLock.lock()
        defer { swizzlingLock.unlock() }
        
        guard !hasSwizzled else { return }
        
        let originalWillAppear = #selector(viewWillAppear(_:))
        let swizzledWillAppear = #selector(easyLogger_viewWillAppear(_:))
        
        let originalDidAppear = #selector(viewDidAppear(_:))
        let swizzledDidAppear = #selector(easyLogger_viewDidAppear(_:))
        
        guard let originalWillAppearMethod = class_getInstanceMethod(UIViewController.self, originalWillAppear),
              let swizzledWillAppearMethod = class_getInstanceMethod(UIViewController.self, swizzledWillAppear),
              let originalDidAppearMethod = class_getInstanceMethod(UIViewController.self, originalDidAppear),
              let swizzledDidAppearMethod = class_getInstanceMethod(UIViewController.self, swizzledDidAppear)
        else { return }
        
        // We need to add the methods first to handle cases where they might not exist
        let willAppearDidAdd = class_addMethod(
            UIViewController.self,
            originalWillAppear,
            method_getImplementation(swizzledWillAppearMethod),
            method_getTypeEncoding(swizzledWillAppearMethod)
        )
        
        let didAppearDidAdd = class_addMethod(
            UIViewController.self,
            originalDidAppear,
            method_getImplementation(swizzledDidAppearMethod),
            method_getTypeEncoding(swizzledDidAppearMethod)
        )
        
        if willAppearDidAdd {
            class_replaceMethod(
                UIViewController.self,
                swizzledWillAppear,
                method_getImplementation(originalWillAppearMethod),
                method_getTypeEncoding(originalWillAppearMethod)
            )
        } else {
            method_exchangeImplementations(originalWillAppearMethod, swizzledWillAppearMethod)
        }
        
        if didAppearDidAdd {
            class_replaceMethod(
                UIViewController.self,
                swizzledDidAppear,
                method_getImplementation(originalDidAppearMethod),
                method_getTypeEncoding(originalDidAppearMethod)
            )
        } else {
            method_exchangeImplementations(originalDidAppearMethod, swizzledDidAppearMethod)
        }
        
        hasSwizzled = true
    }
    
    /// Restore original method implementations
    static func tearDownScreenTimeTracking() {
        swizzlingLock.lock()
        defer { swizzlingLock.unlock() }
        
        guard hasSwizzled else { return }
        
        let originalWillAppear = #selector(viewWillAppear(_:))
        let swizzledWillAppear = #selector(easyLogger_viewWillAppear(_:))
        
        let originalDidAppear = #selector(viewDidAppear(_:))
        let swizzledDidAppear = #selector(easyLogger_viewDidAppear(_:))
        
        guard let originalWillAppearMethod = class_getInstanceMethod(UIViewController.self, originalWillAppear),
              let swizzledWillAppearMethod = class_getInstanceMethod(UIViewController.self, swizzledWillAppear),
              let originalDidAppearMethod = class_getInstanceMethod(UIViewController.self, originalDidAppear),
              let swizzledDidAppearMethod = class_getInstanceMethod(UIViewController.self, swizzledDidAppear)
        else { return }
        
        method_exchangeImplementations(swizzledWillAppearMethod, originalWillAppearMethod)
        method_exchangeImplementations(swizzledDidAppearMethod, originalDidAppearMethod)
        
        hasSwizzled = false
    }
    
    @objc private func easyLogger_viewWillAppear(_ animated: Bool) {
        easyLogger_viewWillAppear(animated)
        guard !isSystemViewController else { return }
        EasyLogger.shared.trackScreenAppearance(self)
    }
    
    @objc private func easyLogger_viewDidAppear(_ animated: Bool) {
        easyLogger_viewDidAppear(animated)
        guard !isSystemViewController else { return }
        EasyLogger.shared.endScreenTracking(self)
    }
    
    /// Check if the view controller is a system one that we should ignore
    private var isSystemViewController: Bool {
        let viewControllerName = String(describing: type(of: self))
        return viewControllerName.hasPrefix("UI") ||
               viewControllerName.hasPrefix("_UI") ||
               self is UINavigationController ||
               self is UITabBarController ||
               self is UIAlertController ||
               self is UIActivityViewController
    }
} 