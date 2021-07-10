import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_virtual_directory/shelf_virtual_directory.dart';
import 'package:test/test.dart';

void main() {
  // Tests uses different root directory
  // so we need to append current directory path
  //
  // "web" is the folder that we are trying to serve
  final fsPath = p.join(Directory.current.path, 'test', 'web');

  // final vWebDir = ShelfVirtualDirectory('fsPath');
  test('Throws "ArgumentError" when directory is not found', () {
    expect(() => ShelfVirtualDirectory('doesnotexist'), throwsArgumentError);
  });

  group('Test API calls', () {
    late io.IOServer server;

    setUpAll(() async {
      final virDir = ShelfVirtualDirectory(fsPath);

      final router = Router()
        ..mount('/nodirlisting/',
            ShelfVirtualDirectory(fsPath, listDirectory: false).handler)
        ..mount('/routerstatic/', virDir.router)
        ..mount('/mountstatic/', virDir.handler)
        // only offline tests are possible
        ..mount('/fsrootstatic/', ShelfVirtualDirectory('/').handler)
        // for testing customheader
        ..mount(
            '/customheader/',
            ShelfVirtualDirectory(fsPath, headersParser: _customHeaderParser)
                .handler)
        ..get('/api/user', (_) => Response.ok('/api/user'))
        ..get('/api', (_) => Response.ok('/api'))
        ..mount('/', ShelfVirtualDirectory('/').handler);

      // setup server test files
      final pipline = const Pipeline()
          // .addMiddleware(logRequests())
          .addHandler(router);

      server = await io.IOServer.bind(InternetAddress.loopbackIPv4, 0)
        ..mount(pipline);
    });

    tearDownAll(() => server.close());

    Uri url(String path) => Uri(
          scheme: server.url.scheme,
          userInfo: server.url.userInfo,
          host: server.url.host,
          port: server.url.port,
          path: path,
          query: server.url.query,
          queryParameters: server.url.queryParameters,
          fragment: server.url.fragment,
        );

    // GET Requests
    test('GET ..mount(\'/routerstatic/\') should return 200', () async {
      final res = await http.get(url('/routerstatic/'));
      expect(res.statusCode, equals(200));
    });

    test('GET ..mount(\'/mountstatic/\') should return 200', () async {
      final res = await http.get(url('/mountstatic/'));
      expect(res.statusCode, equals(200));
    });

    test('GET ..mount(\'/fsrootstatic/\') should return 200', () async {
      final res = await http.get(url('/fsrootstatic/'));
      expect(res.statusCode, equals(200));
      // CI services might not have access to root folder so skipping it
    }, skip: true);

    test('GET ..get(\'/api/user\') should return 200', () async {
      final res = await http.get(url('/api/user'));
      expect(res.statusCode, equals(200));
    });

    test('GET Should redirect if there is no trailing slash "/"', () async {
      final req = http.Request('GET', url('/routerstatic/temp'))
        // ..maxRedirects = 1
        ..followRedirects = false;
      final client = http.Client();

      final rs = await client.send(req);
      client.close();
      expect(rs.isRedirect, isTrue);
      expect(rs.statusCode, equals(301));
      expect(rs.headers[HttpHeaders.locationHeader], isNotNull);
      expect(rs.headers[HttpHeaders.locationHeader], endsWith('/'));
    });

    // HEAD requests
    test('HEAD ..mount(\'/routerstatic/\') should return 200', () async {
      final res = await http.head(url('/routerstatic/'));
      expect(res.statusCode, equals(200));
    });

    test('HRAD ..mount(\'/mountstatic/\') should return 200', () async {
      final res = await http.head(url('/mountstatic/'));
      expect(res.statusCode, equals(200));
    });

    test('HEAD ..mount(\'/fsrootstatic/\') should return 200', () async {
      final res = await http.head(url('/fsrootstatic/'));
      expect(res.statusCode, equals(200));
      // CI services might not have access to root folder so skipping it
    }, skip: true);

    test('HEAD ..get(\'/api/user\') should return 200', () async {
      final res = await http.head(url('/api/user'));
      expect(res.statusCode, equals(200));
    });

    test('HEAD Should redirect if there is no trailing slash "/"', () async {
      final req = http.Request('HEAD', url('/routerstatic/temp'))
        // ..maxRedirects = 1
        ..followRedirects = false;
      final client = http.Client();

      final rs = await client.send(req);
      client.close();
      expect(rs.isRedirect, isTrue);
      expect(rs.statusCode, equals(301));
      expect(rs.headers[HttpHeaders.locationHeader], isNotNull);
      expect(rs.headers[HttpHeaders.locationHeader], endsWith('/'));
    });
    // - listdirectory
    test('Should list directory', () async {
      final res = await http.get(url('/routerstatic/temp/'));
      expect(res.statusCode, equals(200));
    });

    test('Should not list directory', () async {
      final res = await http.get(url('/nodirlisting/temp/'));
      expect(res.statusCode, equals(404));
    });

    test('FileHeaderParser', () async {
      final res = await http.get(url('/customheader/'));
      expect(
        res.headers,
        containsPair('customheader', 'ShelfVirtualDirectory'),
      );
    });
  });
}

Map<String, Object> _customHeaderParser(File file) =>
    {'customheader': 'ShelfVirtualDirectory'};
