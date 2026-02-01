#import <Foundation/Foundation.h>
#import "YeoPeDependencyProvider.h"
#import <ReactCommon/RCTTurboModule.h>

// Forward declaration of BLEModule
@class BLEModule;

@interface YeoPeDependencyProvider : RCTAppDependencyProvider
@end

// BLEModule Provider
@interface BLEModuleProvider : NSObject <RCTModuleProvider>
@end

@implementation BLEModuleProvider

- (id<RCTTurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
    // BLEModule will be instantiated by the TurboModule system
    // We just need to return a new instance
    Class moduleClass = NSClassFromString(@"BLEModule");
    if (moduleClass) {
        return [[moduleClass alloc] init];
    }
    return nil;
}

@end

@implementation YeoPeDependencyProvider

- (NSDictionary<NSString *, id<RCTModuleProvider>> *)moduleProviders {
    // Get parent providers
    NSMutableDictionary *providers = [[super moduleProviders] mutableCopy];
    
    // Add BLEModule manually
    providers[@"BLEModule"] = [[BLEModuleProvider alloc] init];
    
    return providers;
}

@end
