//
//  AudioService.swift
//  RocketBuild
//
//  Minimal sound layer. Sounds are synthesised system-tone stand-ins so the
//  game ships with no audio assets; real files can be dropped in later and
//  mapped by the same Cue enum. Injected, never a singleton.
//

import AVFoundation
import AudioToolbox

final class AudioService {

    enum Cue {
        case launch, engine, explosion, coin, magnet, shield, warning
    }

    private var enabled = true

    func setEnabled(_ on: Bool) { enabled = on }

    /// Plays a short cue. Uses system sound IDs as lightweight placeholders.
    func play(_ cue: Cue) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(systemSoundID(for: cue))
    }

    private func systemSoundID(for cue: Cue) -> SystemSoundID {
        // Map cues onto distinct built-in tones. These are placeholders and are
        // intentionally kept in one place for easy replacement with real assets.
        switch cue {
        case .launch:    return 1519
        case .engine:    return 1520
        case .explosion: return 1521
        case .coin:      return 1057
        case .magnet:    return 1103
        case .shield:    return 1104
        case .warning:   return 1005
        }
    }
}
