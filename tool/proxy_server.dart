import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';

// Simple dev proxy to bypass CORS for Flutter web.
// Usage: dart run tool/proxy_server.dart
// Proxies: http://localhost:8081/xmlrpc/2/* -> https://pointy.dbc.ma/xmlrpc/2/*

void main(List<String> args) async {
  final targetBase = Uri.parse('https://pointy.dbc.ma');

  // Proxy handler for /xmlrpc/*
  // Changed: proxyHandler returns a Handler function, so we need to store it differently
  final proxy = proxyHandler(targetBase.origin);

  // Add CORS headers
  Response addCors(Response response) => response.change(headers: {
        ...response.headers,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
      });

  final handler =
      const Pipeline().addMiddleware(logRequests()).addMiddleware((innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        });
      }
      // Fixed: proxy is a Handler function, call it and await the result
      final Response resp = await proxy(request);
      return addCors(resp);
    };
  }).addHandler((Request req) async {
    // Only allow /xmlrpc/* to be proxied
    if (req.url.pathSegments.isNotEmpty &&
        req.url.pathSegments.first == 'xmlrpc') {
      // Fixed: proxy is a Handler function, call it and return the result
      return await proxy(req);
    }
    return Response.notFound('Proxy running. Use /xmlrpc/...');
  });

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8081;
  final server = await io.serve(handler, InternetAddress.loopbackIPv4, port);
  print(
      'Proxy listening on http://localhost:${server.port} -> ${targetBase.origin}');
}