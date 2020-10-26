import 'dart:io';

import 'package:shelf/shelf.dart' show Cascade, Pipeline, logRequests;
import 'package:shelf/shelf_io.dart' as io show serve;

import 'package:shelf_virtual_directory/shelf_virtual_directory.dart'
    show ShelfVirtualDirectory;

void main(List<String> args) {
  // serving directory
  const folderToServe = 'web';
  final address = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8082');

  // creates a [ShelfVirtualDirectory] instance and provides a [Router] instance.
  final virDirRouter = ShelfVirtualDirectory(folderToServe);

  // using [Pipeline] from shelf we can add a logging middleware.
  // we can use handler provided by [Router] instance.
  final staticFileHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(virDirRouter.handler);

  // add the handler to [Cascade]
  io
      .serve(
        Cascade().add(staticFileHandler).handler,
        address,
        port,
      )
      .then(
        (server) =>
            print('Server is sunning at ${server.address}:${server.port}'),
      );
}
