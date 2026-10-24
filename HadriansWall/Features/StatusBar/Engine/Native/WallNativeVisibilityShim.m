//
//  WallNativeVisibilityShim.m
//  Hadrian's Wall
//

#import "WallNativeVisibilityShim.h"

static NSString *const WallNativeVisibilityErrorDomain = @"WallNativeVisibility";

static NSError *WallNativeVisibilityError(NSString *reason) {
    return [NSError errorWithDomain:WallNativeVisibilityErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

#if NATIVE_VISIBILITY

#import <dlfcn.h>
#import <objc/message.h>

// MenuBarClientCore is the private framework behind macOS 27's assessment
// (exam lockdown) mode, which can restrict the menu bar to an allow-list. It is
// resolved at runtime so a macOS release that changes or removes it turns into
// "unavailable" rather than a launch failure. Names are spelled out on purpose.
static NSString *const WallFrameworkPath = @"/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";
static NSString *const WallConfigurationClassName = @"MBAssessmentModeConfiguration";
static NSString *const WallAssertionClassName = @"MBAssessmentModeAssertion";

static SEL WallConfigurationInit(void) { return @selector(initWithAllowedSystemItems:allowedBundleIdentifiers:); }
static SEL WallActivate(void) { return @selector(activateWithConfiguration:completionHandler:); }
static SEL WallInvalidate(void) { return @selector(invalidate); }

BOOL WallNativeVisibilityIsAvailable(void) {
    if (!dlopen(WallFrameworkPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL)) {
        return NO;
    }
    Class configuration = NSClassFromString(WallConfigurationClassName);
    Class assertion = NSClassFromString(WallAssertionClassName);
    return configuration && assertion
        && [configuration instancesRespondToSelector:WallConfigurationInit()]
        && [assertion instancesRespondToSelector:WallActivate()]
        && [assertion instancesRespondToSelector:WallInvalidate()];
}

void WallNativeVisibilityActivate(NSArray<NSNumber *> *allowedSystemItems,
                                NSArray<NSString *> *allowedBundleIdentifiers,
                                void (^completion)(id _Nullable assertion, NSError * _Nullable error)) {
    void (^finish)(id, NSError *) = ^(id assertion, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(assertion, error); });
    };
    if (!WallNativeVisibilityIsAvailable()) {
        finish(nil, WallNativeVisibilityError(@"MenuBarClientCore is unavailable on this macOS"));
        return;
    }
    @try {
        // Both lists must be NSArrays: the framework indexes into them, and an
        // NSSet raises -objectAtIndex: unrecognized.
        id configuration = ((id (*)(id, SEL, NSArray *, NSArray *))objc_msgSend)(
            [NSClassFromString(WallConfigurationClassName) alloc], WallConfigurationInit(),
            [allowedSystemItems copy], [allowedBundleIdentifiers copy]);
        id assertion = [[NSClassFromString(WallAssertionClassName) alloc] init];
        if (!configuration || !assertion) {
            finish(nil, WallNativeVisibilityError(@"Could not create the visibility configuration"));
            return;
        }
        ((void (*)(id, SEL, id, void (^)(NSError *)))objc_msgSend)(
            assertion, WallActivate(), configuration, ^(NSError *error) {
                finish(error ? nil : assertion, error);
            });
    } @catch (NSException *exception) {
        finish(nil, WallNativeVisibilityError([NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]));
    }
}

void WallNativeVisibilityInvalidate(id assertion) {
    @try {
        if ([assertion respondsToSelector:WallInvalidate()]) {
            ((void (*)(id, SEL))objc_msgSend)(assertion, WallInvalidate());
        }
    } @catch (NSException *exception) {
        NSLog(@"NativeVisibility: invalidate raised %@: %@", exception.name, exception.reason);
    }
}

#else

BOOL WallNativeVisibilityIsAvailable(void) {
    return NO;
}

void WallNativeVisibilityActivate(NSArray<NSNumber *> *allowedSystemItems,
                                NSArray<NSString *> *allowedBundleIdentifiers,
                                void (^completion)(id _Nullable assertion, NSError * _Nullable error)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, WallNativeVisibilityError(@"Native visibility is not part of this build"));
    });
}

void WallNativeVisibilityInvalidate(id assertion) {
}

#endif
