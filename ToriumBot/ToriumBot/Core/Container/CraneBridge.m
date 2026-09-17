#import "CraneBridge.h"
#import <dlfcn.h>
#import <spawn.h>
#import <objc/runtime.h>

@interface NSObject (CraneManagerDeclarations)
+ (id)sharedManager;
- (NSArray*)containerIdentifiersOfApplicationWithIdentifier:(NSString*)applicationID;
- (NSString*)createNewContainerWithName:(NSString*)containerName forApplicationWithIdentifier:(NSString*)applicationID;
- (void)setActiveContainerIdentifier:(NSString*)containerID forApplicationWithIdentifier:(NSString*)applicationID;
- (void)deleteContainerWithIdentifier:(NSString*)containerID forApplicationWithIdentifier:(NSString*)applicationID;
- (NSDictionary*)pathsAssociatedToContainerWithIdentifier:(NSString*)containerID ofApplicationWithIdentifier:(NSString*)applicationID;
- (void)flushCFPrefsdCacheForApplicationWithIdentifier:(NSString*)applicationID;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString*)bundleID;
@end

@implementation CraneBridge

+ (id)getCraneManagerInstance {
    static id sCraneManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char* candidatePaths[] = {
            "/usr/lib/libcrane.dylib",
            "/var/jb/usr/lib/libcrane.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/libcrane.dylib",
            "/var/jb/Library/MobileSubstrate/DynamicLibraries/libcrane.dylib",
            "/var/jb/Library/Frameworks/Crane.framework/Crane"
        };
        void* handle = NULL;
        for (int i = 0; i < sizeof(candidatePaths)/sizeof(candidatePaths[0]); i++) {
            handle = dlopen(candidatePaths[i], RTLD_NOW);
            if (handle) break;
        }
        Class craneClass = NSClassFromString(@"CraneManager");
        if (craneClass && [craneClass respondsToSelector:@selector(sharedManager)]) {
            sCraneManager = [craneClass sharedManager];
        }
    });
    return sCraneManager;
}

+ (NSArray<NSString*>*)getContainersForApp:(NSString*)bundleId {
    id mgr = [self getCraneManagerInstance];
    if (mgr && [mgr respondsToSelector:@selector(containerIdentifiersOfApplicationWithIdentifier:)]) {
        return [mgr containerIdentifiersOfApplicationWithIdentifier:bundleId] ?: @[];
    }
    return @[];
}

+ (nullable NSString*)createContainerNamed:(NSString*)name forApp:(NSString*)bundleId {
    id mgr = [self getCraneManagerInstance];
    if (mgr && [mgr respondsToSelector:@selector(createNewContainerWithName:forApplicationWithIdentifier:)]) {
        return [mgr createNewContainerWithName:name forApplicationWithIdentifier:bundleId];
    }
    return nil;
}

+ (void)switchContainer:(NSString*)containerId forApp:(NSString*)bundleId {
    // Step 1: Terminate running app instances to avoid cache corruption
    system("killall -9 Torium 2>/dev/null");
    
    // Step 2: Switch active container in Crane
    id mgr = [self getCraneManagerInstance];
    if (mgr && [mgr respondsToSelector:@selector(setActiveContainerIdentifier:forApplicationWithIdentifier:)]) {
        [mgr setActiveContainerIdentifier:containerId forApplicationWithIdentifier:bundleId];
    }
    
    // Step 3: Flush Preferences daemon cache
    if (mgr && [mgr respondsToSelector:@selector(flushCFPrefsdCacheForApplicationWithIdentifier:)]) {
        [mgr flushCFPrefsdCacheForApplicationWithIdentifier:bundleId];
    }
}

+ (void)deleteContainer:(NSString*)containerId forApp:(NSString*)bundleId {
    id mgr = [self getCraneManagerInstance];
    if (mgr && [mgr respondsToSelector:@selector(deleteContainerWithIdentifier:forApplicationWithIdentifier:)]) {
        [mgr deleteContainerWithIdentifier:containerId forApplicationWithIdentifier:bundleId];
    }
}

+ (NSDictionary<NSNumber*, NSString*>*)getContainerPaths:(NSString*)containerId forApp:(NSString*)bundleId {
    id mgr = [self getCraneManagerInstance];
    if (mgr && [mgr respondsToSelector:@selector(pathsAssociatedToContainerWithIdentifier:ofApplicationWithIdentifier:)]) {
        return [mgr pathsAssociatedToContainerWithIdentifier:containerId ofApplicationWithIdentifier:bundleId] ?: @{};
    }
    return @{};
}

+ (void)cleanContainerCaches:(NSString*)containerId forApp:(NSString*)bundleId {
    NSDictionary* paths = [self getContainerPaths:containerId forApp:bundleId];
    // ContainerPathTypeApp is key 0
    NSString* appSandboxPath = paths[@(0)] ?: paths[@"0"];
    if (appSandboxPath && [appSandboxPath isKindOfClass:[NSString class]]) {
        NSFileManager* fm = [NSFileManager defaultManager];
        NSString* cachesDir = [appSandboxPath stringByAppendingPathComponent:@"Library/Caches"];
        NSString* webkitDir = [appSandboxPath stringByAppendingPathComponent:@"Library/WebKit"];
        
        [fm removeItemAtPath:cachesDir error:nil];
        [fm removeItemAtPath:webkitDir error:nil];
    }
}

+ (BOOL)launchApplicationWithIdentifier:(NSString*)bundleId {
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    if (wsClass && [wsClass respondsToSelector:@selector(defaultWorkspace)]) {
        id workspace = [wsClass defaultWorkspace];
        if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            return [workspace openApplicationWithBundleID:bundleId];
        }
    }
    return NO;
}

@end
