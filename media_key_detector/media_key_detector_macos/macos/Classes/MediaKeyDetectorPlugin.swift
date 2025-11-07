import FlutterMacOS
import MediaPlayer
import Foundation

public class MediaKeyDetectorPlugin: NSObject, FlutterPlugin, FlutterAppLifecycleDelegate {
    private var mediaKeyHandler = MediaKeyHandler()
    var isNowPlayable = false
    var playPauseTarget: Any?;
    var previousTrackTarget: Any?;
    var nextTrackTarget: Any?;

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "media_key_detector_macos",
            binaryMessenger: registrar.messenger)
        
        // Setup an event channel in addition to the method channel. This will react to native events and then notify Dart code.
        let eventChannel = FlutterEventChannel(
            name: "media_key_detector_macos_events",
            binaryMessenger: registrar.messenger)
        
        let instance = MediaKeyDetectorPlugin()
        
        // Add the MediaKeyHandler to the event channel stream
        eventChannel.setStreamHandler(instance.mediaKeyHandler)
        
        // Register the instance to listen to method calls from Dart
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Register the instance to handle the FlutterAppLifecycle
        registrar.addApplicationDelegate(instance)
    }
    
    func makeNowPlayable() throws {
        if (isNowPlayable) {
            return
        }
        
        let commandCenter = MPRemoteCommandCenter.shared()
        self.playPauseTarget = commandCenter.togglePlayPauseCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            self.mediaKeyHandler.onKeyEvent(key: 0);
            MPNowPlayingInfoCenter.default().playbackState = MPNowPlayingInfoCenter.default().playbackState == .playing ? .paused : .playing
            return .success
        }
        self.previousTrackTarget = commandCenter.previousTrackCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            self.mediaKeyHandler.onKeyEvent(key: 1);
            return .success
        }
        self.nextTrackTarget = commandCenter.nextTrackCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            self.mediaKeyHandler.onKeyEvent(key: 2);
            return .success
        }
        MPNowPlayingInfoCenter.default().playbackState = .playing
        MPNowPlayingInfoCenter.default().playbackState = .paused
        isNowPlayable = true
    }
    
    public func handleDidBecomeActive(_ notification: Notification) {
        do {
            try makeNowPlayable()
        }
        catch {
            print(error)
        }
    }
    
    public func handleDidFinishLaunching(_ notification: Notification) {
        do {
            try makeNowPlayable()
        }
        catch {
            print(error)
        }
    }
    
    public func handleWillTerminate(_ notification: Notification) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.removeTarget(self.playPauseTarget)
        commandCenter.togglePlayPauseCommand.removeTarget(self.previousTrackTarget)
        commandCenter.togglePlayPauseCommand.removeTarget(self.nextTrackTarget)
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformName":
            result("MacOS")
        case "getIsPlaying":
            result(MPNowPlayingInfoCenter.default().playbackState == .playing)
        case "setIsPlaying":
            guard let args = call.arguments as? Dictionary<String, Any> else {return}
            let isPlaying = args["isPlaying"] as! Bool
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class MediaKeyHandler: NSObject, FlutterStreamHandler {
    // Declare our eventSink, it will be initialized later
    private var eventSink: FlutterEventSink?
    
    func onKeyEvent(key: Int32) {
        self.eventSink?(key)
    }
    
    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
