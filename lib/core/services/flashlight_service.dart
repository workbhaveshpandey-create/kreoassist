import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:torch_light/torch_light.dart';

/// Flashlight Service with SOS Morse Code support
/// SOS Pattern: ... --- ... (3 short, 3 long, 3 short)
class FlashlightService {
  static bool _isFlashlightOn = false;
  static bool _isSOSActive = false;
  static Timer? _sosTimer;

  // Morse Code Timing (in milliseconds)
  static const int _dotDuration = 200; // Short blink
  static const int _dashDuration = 600; // Long blink
  static const int _symbolGap = 200; // Gap between dots/dashes
  static const int _letterGap = 600; // Gap between letters
  static const int _wordGap = 1400; // Gap after full SOS

  /// Check if device has flashlight
  static Future<bool> hasFlashlight() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (e) {
      debugPrint('Flashlight check failed: $e');
      return false;
    }
  }

  /// Get flashlight state
  static bool get isOn => _isFlashlightOn;
  static bool get isSOSActive => _isSOSActive;

  /// Toggle flashlight
  static Future<void> toggle() async {
    if (_isSOSActive) {
      await stopSOS();
    }

    try {
      if (_isFlashlightOn) {
        await TorchLight.disableTorch();
        _isFlashlightOn = false;
      } else {
        await TorchLight.enableTorch();
        _isFlashlightOn = true;
      }
    } catch (e) {
      debugPrint('Flashlight toggle failed: $e');
    }
  }

  /// Turn on flashlight
  static Future<void> turnOn() async {
    if (_isFlashlightOn) return;
    try {
      await TorchLight.enableTorch();
      _isFlashlightOn = true;
    } catch (e) {
      debugPrint('Flashlight on failed: $e');
    }
  }

  /// Turn off flashlight
  static Future<void> turnOff() async {
    if (!_isFlashlightOn) return;
    try {
      await TorchLight.disableTorch();
      _isFlashlightOn = false;
    } catch (e) {
      debugPrint('Flashlight off failed: $e');
    }
  }

  /// Start SOS Morse Code pattern
  /// Pattern: ... --- ... (dot dot dot, dash dash dash, dot dot dot)
  static Future<void> startSOS({VoidCallback? onCycleComplete}) async {
    if (_isSOSActive) return;

    _isSOSActive = true;
    await _runSOSLoop(onCycleComplete: onCycleComplete);
  }

  /// Stop SOS pattern
  static Future<void> stopSOS() async {
    _isSOSActive = false;
    _sosTimer?.cancel();
    _sosTimer = null;
    await turnOff();
  }

  /// Run continuous SOS loop
  static Future<void> _runSOSLoop({VoidCallback? onCycleComplete}) async {
    while (_isSOSActive) {
      // S: ...
      await _blink(_dotDuration);
      await _pause(_symbolGap);
      await _blink(_dotDuration);
      await _pause(_symbolGap);
      await _blink(_dotDuration);
      await _pause(_letterGap);

      if (!_isSOSActive) break;

      // O: ---
      await _blink(_dashDuration);
      await _pause(_symbolGap);
      await _blink(_dashDuration);
      await _pause(_symbolGap);
      await _blink(_dashDuration);
      await _pause(_letterGap);

      if (!_isSOSActive) break;

      // S: ...
      await _blink(_dotDuration);
      await _pause(_symbolGap);
      await _blink(_dotDuration);
      await _pause(_symbolGap);
      await _blink(_dotDuration);
      await _pause(_wordGap);

      onCycleComplete?.call();
    }
  }

  /// Blink flashlight for given duration
  static Future<void> _blink(int durationMs) async {
    if (!_isSOSActive) return;
    await turnOn();
    await Future.delayed(Duration(milliseconds: durationMs));
    await turnOff();
  }

  /// Pause for given duration
  static Future<void> _pause(int durationMs) async {
    await Future.delayed(Duration(milliseconds: durationMs));
  }

  /// Blink custom Morse code pattern
  static Future<void> blinkMorse(String text) async {
    final morse = _textToMorse(text);

    for (final char in morse.split('')) {
      if (!_isSOSActive && char != ' ') continue;

      switch (char) {
        case '.':
          await _blink(_dotDuration);
          await _pause(_symbolGap);
          break;
        case '-':
          await _blink(_dashDuration);
          await _pause(_symbolGap);
          break;
        case ' ':
          await _pause(_letterGap);
          break;
        case '/':
          await _pause(_wordGap);
          break;
      }
    }
  }

  /// Convert text to Morse code
  static String _textToMorse(String text) {
    const morseMap = {
      'A': '.-',
      'B': '-...',
      'C': '-.-.',
      'D': '-..',
      'E': '.',
      'F': '..-.',
      'G': '--.',
      'H': '....',
      'I': '..',
      'J': '.---',
      'K': '-.-',
      'L': '.-..',
      'M': '--',
      'N': '-.',
      'O': '---',
      'P': '.--.',
      'Q': '--.-',
      'R': '.-.',
      'S': '...',
      'T': '-',
      'U': '..-',
      'V': '...-',
      'W': '.--',
      'X': '-..-',
      'Y': '-.--',
      'Z': '--..',
      '0': '-----',
      '1': '.----',
      '2': '..---',
      '3': '...--',
      '4': '....-',
      '5': '.....',
      '6': '-....',
      '7': '--...',
      '8': '---..',
      '9': '----.',
      ' ': '/',
    };

    return text.toUpperCase().split('').map((c) => morseMap[c] ?? '').join(' ');
  }
}
