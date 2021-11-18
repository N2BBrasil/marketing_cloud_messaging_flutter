#import "MarketingCloudMessagingFlutterPlugin.h"
#if __has_include(<marketing_cloud_messaging_flutter/marketing_cloud_messaging_flutter-Swift.h>)
#import <marketing_cloud_messaging_flutter/marketing_cloud_messaging_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "marketing_cloud_messaging_flutter-Swift.h"
#endif

@implementation MarketingCloudMessagingFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMarketingCloudMessagingFlutterPlugin registerWithRegistrar:registrar];
}
@end
