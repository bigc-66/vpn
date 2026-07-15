import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum SpeedTestPhase { idle, ping, download, upload, done }

class SpeedTestService extends ChangeNotifier {
  SpeedTestPhase _phase = SpeedTestPhase.idle;
  double _downloadMbps = 0;
  double _uploadMbps = 0;
  int _pingMs = 0;
  bool _running = false;

  SpeedTestPhase get phase => _phase;
  double get downloadMbps => _downloadMbps;
  double get uploadMbps => _uploadMbps;
  int get pingMs => _pingMs;
  bool get running => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _downloadMbps = 0;
    _uploadMbps = 0;
    _pingMs = 0;
    notifyListeners();

    try {
      _phase = SpeedTestPhase.ping;
      notifyListeners();
      _pingMs = await _measurePing();
      notifyListeners();

      _phase = SpeedTestPhase.download;
      notifyListeners();
      _downloadMbps = await _measureDownload();
      notifyListeners();

      _phase = SpeedTestPhase.upload;
      notifyListeners();
      _uploadMbps = await _measureUpload();
      notifyListeners();

      _phase = SpeedTestPhase.done;
    } catch (_) {
      _phase = SpeedTestPhase.done;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<int> _measurePing() async {
    // 用 HTTP GET 小请求测 RTT，兼容 VPN 隧道环境
    final uri = Uri.parse('https://speed.cloudflare.com/__down?bytes=0');
    final pings = <int>[];
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      try {
        await http.get(uri).timeout(const Duration(seconds: 5));
        sw.stop();
        pings.add(sw.elapsedMilliseconds);
      } catch (_) {
        // skip failed attempt
      }
    }
    if (pings.isEmpty) return -1;
    pings.sort();
    return pings[pings.length ~/ 2];
  }

  Future<double> _measureDownload() async {
    // 使用流式下载，实时计算速度；限时15秒取平均速率
    final client = http.Client();
    try {
      final uri =
          Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000');
      final request = http.Request('GET', uri);
      final response =
          await client.send(request).timeout(const Duration(seconds: 15));

      final sw = Stopwatch()..start();
      int totalBytes = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
        onTimeout: (sink) => sink.close(),
      )) {
        totalBytes += chunk.length;
        // 实时更新下载速度
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        if (elapsed > 0.5) {
          _downloadMbps = (totalBytes * 8) / (elapsed * 1000000);
          notifyListeners();
        }
      }
      sw.stop();
      final seconds = sw.elapsedMilliseconds / 1000.0;
      if (seconds <= 0 || totalBytes == 0) return 0;
      return (totalBytes * 8) / (seconds * 1000000);
    } catch (_) {
      return _downloadMbps; // 返回已测到的值
    } finally {
      client.close();
    }
  }

  Future<double> _measureUpload() async {
    final client = http.Client();
    try {
      final uri = Uri.parse('https://speed.cloudflare.com/__up');
      final data = Uint8List(4000000); // 4 MB
      final request = http.StreamedRequest('POST', uri);
      request.headers['Content-Type'] = 'application/octet-stream';
      request.contentLength = data.length;

      final sw = Stopwatch()..start();
      final responseFuture =
          client.send(request).timeout(const Duration(seconds: 60));

      // 分块写入，实时更新上传速度
      const chunkSize = 65536;
      int sent = 0;
      for (var offset = 0; offset < data.length; offset += chunkSize) {
        final end =
            (offset + chunkSize) < data.length ? offset + chunkSize : data.length;
        request.sink.add(data.sublist(offset, end));
        sent = end;
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        if (elapsed > 0.5) {
          _uploadMbps = (sent * 8) / (elapsed * 1000000);
          notifyListeners();
        }
      }
      await request.sink.close();
      await responseFuture;

      sw.stop();
      final seconds = sw.elapsedMilliseconds / 1000.0;
      if (seconds <= 0 || sent == 0) return 0;
      return (sent * 8) / (seconds * 1000000);
    } catch (_) {
      return _uploadMbps; // 返回已测到的值
    } finally {
      client.close();
    }
  }
}
