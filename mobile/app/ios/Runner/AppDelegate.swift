import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVSpeechSynthesizerDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?
  private var activeUtterance: AVSpeechUtterance?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    speechSynthesizer.delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func finishSpeechIfCurrent(_ utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.activeUtterance === utterance else { return }
      self.activeUtterance = nil
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: [.notifyOthersOnDeactivation]
      )
      self.speechChannel?.invokeMethod("onDone", arguments: nil)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    finishSpeechIfCurrent(utterance)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    finishSpeechIfCurrent(utterance)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Offline Voice Briefing Channel (AVSpeechSynthesizer · th-TH / ms-MY / en-US / zh-CN)
    let channel = FlutterMethodChannel(
      name: "net.yala.floodapp/speech",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    self.speechChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
      switch call.method {
      case "speak":
        guard
          let args = call.arguments as? [String: Any],
          let text = args["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(false)
          return
        }
        let locale = (args["locale"] as? String) ?? "th-TH"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
          ?? AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        // Assign activeUtterance BEFORE stopping prior speech so didCancel from the old
        // utterance never clears the new utterance's speaking state.
        self.activeUtterance = utterance
        if self.speechSynthesizer.isSpeaking {
          self.speechSynthesizer.stopSpeaking(at: .immediate)
        }
        try? AVAudioSession.sharedInstance().setCategory(
          .playback,
          mode: .spokenAudio,
          options: [.duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        self.speechSynthesizer.speak(utterance)
        result(true)
      case "stop":
        self.activeUtterance = nil
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(
          false,
          options: [.notifyOthersOnDeactivation]
        )
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
