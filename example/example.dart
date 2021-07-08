import 'dart:io';

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
  final virDirRouter = ShelfVirtualDirectory(folderToServe);

  // using [Pipeline] from shelf we can add a logging middleware.
  // we can use handler provided by [Router] instance.
  final pipline = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(ShelfVirtualDirectory('web').handler);

  final apiRouter = Router()
    ..mount('/routerstatic/', virDirRouter.router)
    ..mount('/mountstatic/', virDirRouter.handler)
    // servers root dir https://github.com/RatakondalaArun/shelf_virtual_directory/issues/15
    // tests permissions
    ..mount('/fsrootstatic/', ShelfVirtualDirectory('/').handler)
    ..mount('/piplinestatic/', pipline)
    ..get('/getstatic/', virDirRouter.handler)
    ..get('/api/user', (_) => Response.ok('/api/user'))
    ..get('/api', (_) => Response.ok('/api'));

  // add the handler to [Cascade]
  final server = await io.serve(
    apiRouter,
    // virDirRouter.cascade.add(apiRouter).handler,
    address,
    port,
  );

  print('Server is running at http://${server.address.host}:${server.port}');
}
