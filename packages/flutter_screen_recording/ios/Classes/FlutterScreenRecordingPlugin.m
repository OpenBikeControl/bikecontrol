#import "FlutterScreenRecordingPlugin.h"
#import <flutter_screen_recording/flutter_screen_recording-Swift.h>

@implementation FlutterScreenRecordingPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterScreenRecordingPlugin registerWithRegistrar:registrar];
}
@end
