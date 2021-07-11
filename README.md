# Virtual Directory for Shelf

![Pub Version](https://img.shields.io/pub/v/shelf_virtual_directory)

This package provides `Handler`, `Router` and `Cascade` to serve static files from the [*dart shelf server*](https://pub.dev/packages/shelf) and can work with websockets.

| Provider  | UseCase                                                           |
| --------- | ----------------------------------------------------------------- |
| `Handler` | Can be used to serve as a handler for `Pipeline` or for `Cascade` |
| `Router`  | Can be used to mount as a subroute                                |
| `Cascade` | Can be used directly serve from shelf server                      |

## Setup

1) Add to pubspec.yaml file

    ```yaml
    dependencies:
        shelf_virtual_directory: latest_version
    ```

2) Get dependencies

    ```shell
    pub get
    ```

3) Import

   ```dart
   import 'package:shelf_virtual_directory/shelf_virtual_directory.dart';
   import 'package:path/path.dart' as p;
   ```

4) Create a instance of `ShelfVirtualDirectory` with a directory `web`

   ```dart
   final fsPath = p.join(Directory.current.path,'example','web');// path to server
   final virtualDir = ShelfVirtualDirectory(
        fsPath,
        defaultFile:'index.html',
        default404File:'404.html',
    );
   ```

   **Note: `index.html` and `404.html` files must be directly under root folder. In above case under `web/` folder.**

## Handling different cases

- Using as a `Handler`

    ```dart
    final virDirHandler = ShelfVirtualDirectory(fsPath).handler;

    final staticFileHandler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(virDirHandler);//used as a handler

    io.serve(Cascade().add(staticFileHandler).handler,address,port)
    .then((server){
        print('Server is sunning at ${server.address}:${server.port}'),
    });
    ```

- Using as a `Router`

    ```dart
    //As a subroute
    final router = Router()
    ..get('/otherroute',otherRoutehandler)
    ..mount('/',ShelfVirtualDirectory(fsPath).router); // localhost:8080/
    //or

    final router = Router()
    ..get('/otherroute',otherRouteHandler)
    ..mount('/home/',ShelfVirtualDirectory(fsPath).router);//localhost:8080/home/
    ```

    **Note: If your are planning to use it under home directory('/'), always mount or handle the `ShelfVirtualDirectory` at the end.**

    Example

    ```dart
    final mainRoute = Router()
    ..get('/rest',(_)=>Respond.ok('Other routes'))
    ..mount('/',ShelfVirtualDirectory(fsPath).router);
    ```

- Using as a `Cascade`

    ```dart
    import 'package:shelf/shelf_io.dart' as io show serve;

    // You can add other handlers to this cascade
    final virDirCascade = ShelfVirtualDirectory(fsPath).cascade;
    io.serve(virDirCascade.add(someOtherHandler),'localhost',8080)
    .then((server){
      print('Server is sunning at ${server.address}:${server.port}'),
    })
    ```

## Limitations

- Only `mount` method supports for the router.

    ```dart
    final router = Router()
        ..mount('/home/',virDir.handler)
        ..get('/api',apiHandler);
    ```

## Contrubitions

**All contrubitions are welcomed.**
