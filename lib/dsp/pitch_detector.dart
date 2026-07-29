import 'dart:math' as math;
import 'dart:typed_data';

/// Autocorrelation-based pitch detector, ported from the original
/// Semitone Android app's DSP.java (Cooley-Tukey FFT + autocorrelation
/// peak picking with quadratic interpolation).
class PitchDetector {
  PitchDetector(int bufferSize) {
    fftPow = 31 - _numberOfLeadingZeros(bufferSize);
    fftLen = 1 << fftPow;

    _cosTable = Float64List(fftLen ~/ 2);
    _sinTable = Float64List(fftLen ~/ 2);
    for (var i = 0; i < fftLen ~/ 2; ++i) {
      _cosTable[i] = math.cos(-2 * math.pi * i / fftLen);
      _sinTable[i] = math.sin(-2 * math.pi * i / fftLen);
    }
  }

  late final int fftPow;
  late final int fftLen;
  late final Float64List _cosTable;
  late final Float64List _sinTable;

  static int _numberOfLeadingZeros(int i) {
    if (i <= 0) return i == 0 ? 32 : 0;
    var n = 31;
    if (i >= 1 << 16) {
      n -= 16;
      i >>= 16;
    }
    if (i >= 1 << 8) {
      n -= 8;
      i >>= 8;
    }
    if (i >= 1 << 4) {
      n -= 4;
      i >>= 4;
    }
    if (i >= 1 << 2) {
      n -= 2;
      i >>= 2;
    }
    return n - (i >> 1);
  }

  // In-place Cooley-Tukey FFT.
  void _fft(Float64List re, Float64List im) {
    // bit reversal
    var j = 0;
    final n2Init = fftLen ~/ 2;
    for (var i = 1; i < fftLen - 1; ++i) {
      var n1 = n2Init;
      while (j >= n1) {
        j -= n1;
        n1 ~/= 2;
      }
      j += n1;

      if (i < j) {
        var tmp = re[i];
        re[i] = re[j];
        re[j] = tmp;
        tmp = im[i];
        im[i] = im[j];
        im[j] = tmp;
      }
    }

    var n2 = 1;
    for (var i = 0; i < fftPow; ++i) {
      final n1 = n2;
      n2 *= 2;
      var a = 0;
      for (var jj = 0; jj < n1; ++jj) {
        for (var k = jj; k < fftLen; k += n2) {
          final tre =
              _cosTable[a] * re[k + n1] - _sinTable[a] * im[k + n1];
          final tim =
              _sinTable[a] * re[k + n1] + _cosTable[a] * im[k + n1];
          re[k + n1] = re[k] - tre;
          im[k + n1] = im[k] - tim;
          re[k] += tre;
          im[k] += tim;
        }
        a += 1 << (fftPow - i - 1);
      }
    }
  }

  // In-place autocorrelation (scaled by N, doesn't matter for peak picking).
  void _autocorr(Float64List are) {
    final aim = Float64List(fftLen);
    _fft(are, aim);
    for (var i = 0; i < fftLen; ++i) {
      // corr(a, a) = ifft(fft(a) * conj(fft(a)))
      are[i] = are[i] * are[i] + aim[i] * aim[i];
      aim[i] = 0;
    }
    _fft(aim, are); // inverse fft
  }

  /// Estimate the fundamental frequency (Hz) of [buf] (length == fftLen)
  /// sampled at [sampleRate]. Returns null if no clear pitch was found.
  double? frequency(Float64List buf, num sampleRate) {
    _autocorr(buf);

    var looking = false;
    var maxVal = 0.0;
    var j = -1;
    for (var i = 0; i < fftLen ~/ 2; ++i) {
      if (looking) {
        final weighted = buf[i];
        if (weighted > maxVal) {
          maxVal = weighted;
          j = i;
        }
      } else {
        looking = buf[i] < 0;
      }
    }

    if (j <= 0 || j >= fftLen ~/ 2 - 1) return null;

    final denom = buf[j - 1] - 2 * buf[j] + buf[j + 1];
    final interp = denom == 0 ? 0.0 : 0.5 * (buf[j - 1] - buf[j + 1]) / denom;
    return sampleRate / (j + interp);
  }
}
