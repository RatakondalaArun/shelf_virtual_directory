library shelf_virtual_directory;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mime/mime.dart' as mime;

class ShelfVirtualDirectory {
  final String folderPath;
  final String defaultFile;
  final String default404File;
  final bool showLogs;
  final Router _router;
  final Directory _rootDir;

  Router get router => _router;

  ShelfVirtualDirectory(
    this.folderPath, {
    this.defaultFile = 'index.html',
    this.default404File = '404.html',
    this.showLogs = true,
  })  : _rootDir = Directory(Platform.script.resolve(folderPath).toFilePath()),
        _router = Router() {
    _initilizeRoutes();
  }

  // initilize route
  Future<void> _initilizeRoutes() async {
    if (!await _rootDir.exists()) {
      throw ArgumentError(
        'A directory corresponding to folderPath '
        '"$folderPath" could not be found',
      );
    }
    // collects all the files from the
    final rootDirSubFolders =
        await _rootDir.list(recursive: true, followLinks: true).toList();
    final rootFolderName = ([..._rootDir.uri.pathSegments]..removeLast()).last;

    for (var entity in rootDirSubFolders) {
      final fileName = entity.uri.pathSegments.last;
      // filters out files from the folders
      if (fileName.isNotEmpty) {
        // trims path before [folderPath]
        final filePath = entity.uri;
        final fileRoute = entity.uri.pathSegments
            .sublist(entity.uri.pathSegments.indexOf(rootFolderName) + 1)
            .join('/');
        _logToConsole(
            '✅Found FilePath: /$rootFolderName/$fileRoute | FileName: $fileName | Content-Type: ${mime.lookupMimeType(filePath.path)}');
        // adds file to all the routes
        _router.get('/$fileRoute', (_) => _serveFile(filePath));
      }
    }

    // serves index.html as default file
    await _setUpIndexPage();
    // serves 404.html as default file
    await _setUp404Page();
  }

  Future<void> _setUpIndexPage() async {
    final filePath = '${_rootDir.path}/${defaultFile ?? 'index.html'}';
    final headers = await _getFileHeaders(File(filePath));
    if (headers.isEmpty) {
      // if "index.html" does not exist
      _router.all(
          '/',
          (_) => Response.notFound(
              '"$defaultFile" file does not exist in root directory'));
    }
    _router.all('/', (_) => _serveFile(Uri.file(filePath)));
  }

  Future<void> _setUp404Page() async {
    final filePath = '${_rootDir.path}/${default404File ?? '404.html'}';
    final headers = await _getFileHeaders(File(filePath));
    if (headers.isEmpty) {
      // if "404.html" does not exist
      _router.all('/<.*>', (_) => Response.notFound(':/ No default 404 page'));
    }
    _router.all('/<.*>', (_) => _serveFile(Uri.file(filePath)));
  }

  Future<Response> _serveFile(Uri fileUri) async {
    final file = File.fromUri(fileUri);
    try {
      if (!await file.exists()) {
        // or default 404 page
        return Response.notFound('NotFound');
      }
      return Response(
        200,
        body: file.openRead(),
        headers: await _getFileHeaders(file),
      );
    } catch (e) {
      print(e);
      return Response.internalServerError();
    }
  }

  Future<Map<String, Object>> _getFileHeaders(File file) async {
    if (!await file.exists()) {
      return {};
    }
    return {
      HttpHeaders.contentTypeHeader: mime.lookupMimeType(file.path),
      HttpHeaders.contentLengthHeader: (await file.length()).toString(),
    };
  }

  void _logToConsole(String message) {
    if (showLogs) print('[ShelfVirtualDirectory] $message');
  }
}
