import 'dart:io';

import 'package:shelf/shelf.dart' show Cascade, Pipeline, Response, logRequests;
import 'package:shelf/shelf_io.dart' as io show serve;
import 'package:shelf_router/shelf_router.dart';

import 'package:shelf_virtual_directory/shelf_virtual_directory.dart'
    show ShelfVirtualDirectory;

Future<void> main(List<String> args) async {
  // serving directory
  const folderToServe = 'web';
  final address = InternetAddress.loopbackIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8082');

  // creates a [ShelfVirtualDirectory] instance and provides a [Router] instance.
  final virDirRouter = ShelfVirtualDirectory(folderToServe);

  // using [Pipeline] from shelf we can add a logging middleware.
  // we can use handler provided by [Router] instance.
  final staticFileHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(virDirRouter.handler);

  final apiRouter = Router()
    ..get('/api/users', (req) => Response.ok('users'))
    ..get('/api/test', (req) => Response.ok('test'));

  // add the handler to [Cascade]
  final server = await io.serve(
    Cascade().add(staticFileHandler).add(apiRouter).handler,
    address,
    port,
  );

  print('Server is running at http://${server.address.host}:${server.port}');
}
