import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _kPrimaryDownload =
    'https://speed.cloudflare.com/__down?measId=0&bytes=10000000';
const _kFallbackDownload = 'https://proof.ovh.net/files/10Mb.dat';
const _kPrimaryUpload = 'https://speed.cloudflare.com/__up';

/// Measures real download/upload throughput against Cloudflare's speed test
/// endpoints. Returns Mbps as a plain double, or null on any error
/// (timeout, VPN, captive portal, HTTP error).
class SpeedTestService {
  /// Provide [client] in tests to avoid real network calls and skip isolates.
  SpeedTestService({http.Client? client}) : _testClient = client;

  final http.Client? _testClient;

  Future<double?> measureDownload() {
    final client = _testClient;
    if (client != null) {
      // In tests: run directly with injected client, no isolate.
      return _downloadWithClient(client, _kPrimaryDownload, _kFallbackDownload);
    }
    return compute(_downloadIsolate, null)
        .timeout(const Duration(seconds: 30), onTimeout: () => null)
        .catchError((_) => null as double?);
  }

  Future<double?> measureUpload() {
    final client = _testClient;
    if (client != null) {
      return _uploadWithClient(client, _kPrimaryUpload);
    }
    return compute(_uploadIsolate, null)
        .timeout(const Duration(seconds: 30), onTimeout: () => null)
        .catchError((_) => null as double?);
  }
}

// -- Isolate entry points: top-level functions; create their own http.Client. --

Future<double?> _downloadIsolate(void _) =>
    _downloadWithClient(http.Client(), _kPrimaryDownload, _kFallbackDownload);

Future<double?> _uploadIsolate(void _) =>
    _uploadWithClient(http.Client(), _kPrimaryUpload);

// -- Shared measurement logic --

/// Runs 3 parallel download requests using StreamedResponse.
/// Skips the first 20% of bytes received (TCP slow-start avoidance).
/// Returns median Mbps across successful requests; null if <2 succeed.
Future<double?> _downloadWithClient(
    http.Client client, String primary, String fallback) async {
  Future<double?> singleRequest(String url) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) return null;

      final contentLength = response.contentLength ?? 10 * 1024 * 1024;
      final skipBytes = (contentLength * 0.2).toInt();
      int totalReceived = 0;
      int measuredBytes = 0;
      DateTime? startTime;

      await for (final chunk in response.stream) {
        totalReceived += chunk.length;
        if (totalReceived > skipBytes) {
          startTime ??= DateTime.now();
          final alreadyCounted = measuredBytes;
          measuredBytes += chunk.length;
          if (alreadyCounted == 0 && totalReceived > skipBytes) {
            // Credit only the bytes past the skip threshold in this chunk.
            measuredBytes = totalReceived - skipBytes;
          }
        }
      }

      if (startTime == null || measuredBytes == 0) return null;
      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsedMs <= 0) return null;
      return (measuredBytes * 8) / (elapsedMs / 1000) / 1e6;
    } catch (_) {
      return null;
    }
  }

  // Try primary; fall back on failure.
  final results = await Future.wait(
    [
      singleRequest(primary),
      singleRequest(primary),
      singleRequest(primary),
    ],
    eagerError: false,
  );

  final valid = results.whereType<double>().toList();

  if (valid.length < 2) {
    // Primary failed or insufficient; try fallback once.
    final fb = await singleRequest(fallback);
    if (fb != null) valid.add(fb);
  }

  if (valid.isEmpty) return null;
  valid.sort();
  return valid[valid.length ~/ 2]; // median
}

/// Sends 3 parallel 5 MB POSTs and measures upload throughput.
/// Returns median Mbps; null if all requests fail.
/// Note: no upload fallback URL — Cloudflare failure returns null.
Future<double?> _uploadWithClient(http.Client client, String url) async {
  final payload = Uint8List(5 * 1024 * 1024); // 5 MB of zeros

  Future<double?> singleUpload() async {
    try {
      final request = http.StreamedRequest('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/octet-stream';
      request.headers['Content-Length'] = payload.length.toString();

      final start = DateTime.now();
      request.sink.add(payload);
      await request.sink.close();

      final response = await client.send(request);
      await response.stream.drain<void>();

      if (response.statusCode != 200) return null;
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      if (elapsedMs <= 0) return null;
      return (payload.length * 8) / (elapsedMs / 1000) / 1e6;
    } catch (_) {
      return null;
    }
  }

  final results = await Future.wait(
    [singleUpload(), singleUpload(), singleUpload()],
    eagerError: false,
  );

  final valid = results.whereType<double>().toList();
  if (valid.isEmpty) return null;
  valid.sort();
  return valid[valid.length ~/ 2]; // median
}
