//
//  NativeVisibilityBridge.swift
//  Hadrian's Wall
//

import Foundation

// A held native visibility restriction. Hiding lasts until invalidate() or until
// this process exits, when macOS drops it and restores the bar by itself.
protocol NativeVisibilityAssertion: AnyObject {
    func invalidate()
}

protocol NativeVisibilityProviding: AnyObject {
    var isAvailable: Bool { get }

    // Keeps only these system items and apps visible. The completion runs on the
    // main queue.
    func activate(allowedSystemItems: [Int],
                  allowedBundleIdentifiers: [String],
                  completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void)
}

final class NativeVisibilityBridge: NativeVisibilityProviding {
    var isAvailable: Bool {
        return WallNativeVisibilityIsAvailable()
    }

    func activate(allowedSystemItems: [Int],
                  allowedBundleIdentifiers: [String],
                  completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void) {
        WallNativeVisibilityActivate(allowedSystemItems.map { NSNumber(value: $0) },
                                   allowedBundleIdentifiers) { handle, error in
            if let handle = handle {
                completion(.success(Handle(raw: handle)))
            } else {
                completion(.failure(error ?? NSError(domain: "WallNativeVisibility", code: 2)))
            }
        }
    }

    private final class Handle: NativeVisibilityAssertion {
        private var raw: Any?

        init(raw: Any) {
            self.raw = raw
        }

        func invalidate() {
            guard let raw = raw else { return }
            self.raw = nil
            WallNativeVisibilityInvalidate(raw)
        }

        deinit {
            invalidate()
        }
    }
}
