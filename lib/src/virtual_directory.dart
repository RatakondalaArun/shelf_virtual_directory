library shelf_virtual_directory;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'html_templates.dart';

class ShelfVirtualDirectory {
  final String folderPath;
  final String defaultFile;
  final String default404File;
  final FileHeaderPraser _headersParser;
  final Directory _dir;
  final bool listDirectory;

  ShelfVirtualDirectory(
    this.folderPath, {
    this.defaultFile = 'index.html',
    this.default404File = '404.html',
    this.listDirectory = true,
    FileHeaderPraser headersPraser = _defaultFileheaderPraser,
  })  : _dir = Directory(path.fromUri(Platform.script.resolve(folderPath))),
        _headersParser = headersPraser {
    if (!_dir.existsSync()) {
      throw ArgumentError('A directory corresponding to folderpath '
          '"$folderPath" could not be found');
    }
  }

  Handler get handler => _handler;
  Router get router => Router(notFoundHandler: _handler);
  Cascade get cascade => Cascade().add(_handler);

  Future<Response> _handler(Request req) async {
    if (req.method != 'GET') return Response.notFound('Not Found');

    final basePath = await _dir.resolveSymbolicLinks();
    final fsPath = path.joinAll([basePath, ...req.url.pathSegments]);

    // checks if index file should be served
    final fsPathType = await FileSystemEntity.type(fsPath);

    print(
        'fsPath: $fsPath, reqpath: ${req.url.path} listDir: $listDirectory, fsPathType: $fsPathType');

    // if (fsPathType == FileSystemEntityType.notFound) {
    //   final indexFile = File(path.join(basePath, defaultFile));
    //   if (!await indexFile.exists()) return Response.notFound('Not Found');
    //   final headers = await _headersParser(indexFile);
    //   return Response(200, body: indexFile.openRead(), headers: headers);
    // }

    // checks if we should serve index file aka `defaultFile`
    if (req.url.path.isEmpty) {
      final indexFile = File(path.join(basePath, defaultFile));
      // if index file exists in that directory serve it
      if (await indexFile.exists()) {
        final headers = await _headersParser(indexFile);
        return Response(200, body: indexFile.openRead(), headers: headers);
      }
      return _handleDir(
        req,
        req.url.path,
        basePath,
        Directory(fsPath),
        _headersParser,
      );
    }

    switch (fsPathType) {
      case FileSystemEntityType.link:
      // todo: handle symboliclinks
      case FileSystemEntityType.directory:
        return _handleDir(
          req,
          req.url.path,
          basePath,
          Directory(fsPath),
          _headersParser,
        );
      case FileSystemEntityType.file:
        return _handleFile(basePath, File(fsPath), _headersParser);
      default:
        return _handleFile(basePath, null, _headersParser);
    }
  }

  Future<Response> _handleFile(
    String fsPath,
    File? file,
    FileHeaderPraser headerPraser,
  ) async {
    // serves default404file incase requested file does not exist
    if (file == null) {
      final notFoundFile = File(path.join(fsPath, default404File));
      if (!await notFoundFile.exists()) return Response.notFound('Not Found');

      return Response.notFound(
        notFoundFile.openRead(),
        headers: await _headersParser(notFoundFile),
      );
    }

    // collect file data
    final fileStat = await file.stat();

    // check file permission
    if (fileStat.modeString()[0] != 'r') return Response.forbidden('Forbidden');

    return Response(
      200,
      body: file.openRead(),
      headers: await headerPraser(file),
    );
  }

  Future<Response> _handleDir(
    Request req,
    String requestedPath,
    String fsPath,
    Directory dir,
    FileHeaderPraser headerPraser,
  ) async {
    if (!listDirectory) return Response.notFound('Not Found');
    if (!requestedPath.endsWith('/') && requestedPath.isNotEmpty) {
      return Response.movedPermanently('${req.requestedUri.toString()}/');
    }

    final dirStat = await dir.stat();
    print(dirStat.modeString());

    // check for directory permission
    // if (dirStat.modeString()[0] != 'r') return Response.forbidden('Forbidden');

    final controller = StreamController<List<int>>();
    const encoding = Utf8Codec();
    const sanitizer = HtmlEscape();

    void add(String string) {
      controller.add(encoding.encode(string));
    }

    add(_listDirhtmlStart(
      sanitizer.convert(Uri.file(dir.path).pathSegments.last),
      sanitizer.convert(requestedPath),
    ));

    final segments = requestedPath.split('/');
    if (segments.isNotEmpty && segments.length > 2) {
      add('''
  <tr>
    <td><a style="cursor: pointer;" onclick="window.location.href = '../'">..</a></td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
  </tr>
''');
    }

    try {
      final subEntities = await dir.list().toList();
      subEntities.sort((e1, e2) {
        if (e1 is Directory && e2 is! Directory) {
          return -1;
        }
        if (e1 is! Directory && e2 is Directory) {
          return 1;
        }
        return e1.path.compareTo(e2.path);
      });

      for (var subEntity in subEntities) {
        final entityStat = await subEntity.stat();
        final entityName = Uri.file(subEntity.path).pathSegments.last;
        add(tr(entityName, requestedPath, entityStat));
      }
      add(_tableEnd());
      add('<p>total: ${subEntities.length}</p>');
      add(_listDirHtmlEnd());
      // ignore: unawaited
      controller.close();

      return Response.ok(
        controller.stream,
        encoding: encoding,
        headers: {HttpHeaders.contentTypeHeader: 'text/html'},
      );
    } on FileSystemException catch (err) {
      stderr..writeln(err)..writeln(StackTrace.current);
      return Response.forbidden('Forbidden');
    } catch (e) {
      rethrow;
    }
  }
}

// Prase header and return headers for the file
typedef FileHeaderPraser = FutureOr<Map<String, Object>?> Function(File file);

Future<Map<String, Object>> _defaultFileheaderPraser(File file) async {
  final fileType = mime.lookupMimeType(file.path);

  // collect file data
  final fileStat = await file.stat();

  // check file permission
  if (fileStat.modeString()[0] != 'r') return {};

  return {
    HttpHeaders.contentTypeHeader: fileType ?? 'application/octet-stream',
    HttpHeaders.contentLengthHeader: fileStat.size.toString(),
    HttpHeaders.lastModifiedHeader: fileStat.modified.toString(),
  };
}

String tr(String name, String requestedPath, FileStat stat) {
  final isDir = stat.type == FileSystemEntityType.directory;
  final modified = stat.modified.toLocal();
  return '''
  <tr>
    <td><small>${isDir ? '📁' : '📄'}</small><a href="$name${isDir ? '/' : ''}">$name ${isDir ? '/' : ''}</a></td>
    <td>${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute}</td>
    <td>${stat.modeString()}</td>
    <td>${stat.size / 100} kb</td>
  </tr>
''';
}
