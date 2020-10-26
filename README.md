# shelf_virtual_directory

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
   
    ```
    pub get
    ```
3) Import

   ```dart
   import 'package:shelf_virtual_directory/shelf_virtual_directory.dart';
   ``` 
4) Create a instance of `ShelfVirtualDirectory` with a directory `../web`

   ```dart
   final virtualDir = ShelfVirtualDirectory('../web');
   ```


## Handling different cases

- Using as a `Handler`

    ```dart
    final virDirHandler = ShelfVirtualDirectory('../web').handler;

    final staticFileHandler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(virDirHandler);//used as a handler

    io.serve(Cascade().add(staticFileHandler).handler,address,port).then((server){
         print('Server is sunning at ${server.address}:${server.port}'),
    });
    ```

- Using as a `Router`

    ```dart
    final router = Router('/',ShelfVirtualDirectory('../web').router); // localhost:8080/
    //or
    final router = Router('/home/',ShelfVirtualDirectory('../web').router); //localhost:8080/home/
    ```

- Using as a `Cascade`

    ```dart
    import 'package:shelf/shelf_io.dart' as io show serve;
  
    final cascade = ShelfVirtualDirectory('web').cascade;
    io.serve(cascade,'localhost',8080).then((server){
      print('Server is sunning at ${server.address}:${server.port}'),
    })
    ```


Contrubitions
---
**All contrubitions are welcomed.**
