import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' show Pipeline, Response, logRequests;
import 'package:shelf/shelf_io.dart' as io show serve;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_virtual_directory/shelf_virtual_directory.dart';

Future<void> main(List<String> args) async {
  // serving directory
  const folderToServe = 'web';
  final address = InternetAddress.loopbackIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8082');

  // creates a [ShelfVirtualDirectory] instance and provides a [Router] instance.
  final folderPath = p.join(
    Directory.current.path,
    'example',
    folderToServe,
  );
  final virDir = ShelfVirtualDirectory(folderPath);

  final apiRouter = Router()
    ..mount('/routerstatic/', virDir.router)
    ..mount('/mountstatic/', virDir.handler)
    ..mount('/nodirlisting/',
        ShelfVirtualDirectory(folderPath, listDirectory: false).handler)
    // ..mount('/fsrootstatic/', ShelfVirtualDirectory('/').handler)
    ..get('/getstatic/', virDir.handler)
    ..get('/api/user', (_) => Response.ok('/api/user'))
    ..get('/api', (_) => Response.ok('/api'))
    ..mount('/', virDir.handler);

  // using [Pipeline] from shelf we can add a logging middleware.
  // we can use handler provided by [Router] instance.
  final pipline =
      const Pipeline().addMiddleware(logRequests()).addHandler(apiRouter);

  // add the handler to [Cascade]
  final server = await io.serve(
    pipline,
    address,
    port,
  );

  print('Server is running at http://${server.address.host}:${server.port}');
}
