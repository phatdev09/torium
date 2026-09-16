#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CraneContainerPathType) {
    CraneContainerPathTypeApp = 0,
    CraneContainerPathTypeGroup = 1,
    CraneContainerPathTypePlugin = 2
};

@interface CraneBridge : NSObject

/// Retrieves all container identifiers for a given bundle ID from Crane
+ (NSArray<NSString*>*)getContainersForApp:(NSString*)bundleId NS_SWIFT_NAME(getContainers(forApp:));

/// Creates a new container with the specified name for an app via libCrane
+ (nullable NSString*)createContainerNamed:(NSString*)name forApp:(NSString*)bundleId NS_SWIFT_NAME(createContainer(named:forApp:));

/// Safely switches the active container: terminates running app, switches container, flushes cache
+ (void)switchContainer:(NSString*)containerId forApp:(NSString*)bundleId NS_SWIFT_NAME(switchContainer(_:forApp:));

/// Deletes a container and its contents from Crane
+ (void)deleteContainer:(NSString*)containerId forApp:(NSString*)bundleId NS_SWIFT_NAME(deleteContainer(_:forApp:));

/// Retrieves associated sandbox filesystem paths for a container
+ (NSDictionary<NSNumber*, NSString*>*)getContainerPaths:(NSString*)containerId forApp:(NSString*)bundleId NS_SWIFT_NAME(getContainerPaths(_:forApp:));

/// Cleans WebKit and Caches folders of a container to save storage (<5MB footprint)
+ (void)cleanContainerCaches:(NSString*)containerId forApp:(NSString*)bundleId NS_SWIFT_NAME(cleanContainerCaches(_:forApp:));

/// Launches the app using private iOS workspace API
+ (BOOL)launchApplicationWithIdentifier:(NSString*)bundleId NS_SWIFT_NAME(launchApplication(withIdentifier:));

@end

NS_ASSUME_NONNULL_END
