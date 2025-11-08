import Flutter
import MediaPlayer
import Foundation

public class MediaKeyDetectorPlugin: NSObject, FlutterPlugin {
    private var mediaKeyHandler = MediaKeyHandler()
    var isNowPlayable = false
    var playPauseTarget: Any?;
    var previousTrackTarget: Any?;
    var nextTrackTarget: Any?;
    private var player: AVPlayer?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "media_key_detector_ios",
            binaryMessenger: registrar.messenger())

        // Setup an event channel in addition to the method channel. This will react to native events and then notify Dart code.
        let eventChannel = FlutterEventChannel(
            name: "media_key_detector_ios_events",
            binaryMessenger: registrar.messenger())

        let instance = MediaKeyDetectorPlugin()

        // Add the MediaKeyHandler to the event channel stream
        eventChannel.setStreamHandler(instance.mediaKeyHandler)

        // Register the instance to listen to method calls from Dart
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register the instance to handle the FlutterAppLifecycle
        registrar.addApplicationDelegate(instance)
    }

    func makeNowPlayable() throws {
    
        // 1) Activate audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        
        
        var url = URL(string: "https://github.com/anars/blank-audio/raw/refs/heads/master/5-seconds-of-silence.mp3")!
        
        // 2) Player
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()


        // 2) Seed Now Playing info
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "SwiftControl",
            MPMediaItemPropertyArtist: "SwiftControl",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPMediaItemPropertyPlaybackDuration: 1337,        // nonzero duration helps
            MPNowPlayingInfoPropertyPlaybackRate: 1         // paused
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .paused

        // 3) Enable and add handlers
        let cc = MPRemoteCommandCenter.shared()
        cc.togglePlayPauseCommand.isEnabled = true
        cc.previousTrackCommand.isEnabled = true
        cc.nextTrackCommand.isEnabled = true

    
        playPauseTarget = cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.mediaKeyHandler.onKeyEvent(key: 0)

            let playing = MPNowPlayingInfoCenter.default().playbackState == .playing
            MPNowPlayingInfoCenter.default().playbackState = playing ? .paused : .playing
            info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 0 : 1
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            return .success
        }
        previousTrackTarget = cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.mediaKeyHandler.onKeyEvent(key: 1)
            return .success
        }
        nextTrackTarget = cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.mediaKeyHandler.onKeyEvent(key: 2)
            return .success
        }
        isNowPlayable = true
    }

    public func applicationWillTerminate(_ application: UIApplication) {

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
            if (isPlaying) {
                do {
                    try makeNowPlayable()
                }
                catch {
                    print(error)
                }
           
            } else {
                player?.pause()
                
                let commandCenter = MPRemoteCommandCenter.shared()
                commandCenter.togglePlayPauseCommand.removeTarget(self.playPauseTarget)
                commandCenter.togglePlayPauseCommand.removeTarget(self.previousTrackTarget)
                commandCenter.togglePlayPauseCommand.removeTarget(self.nextTrackTarget)
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
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
