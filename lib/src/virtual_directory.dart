library shelf_virtual_directory;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http_parser/http_parser.dart' as hp;

part 'html_templates.dart';

/// Creates a instance of [ShelfVirtualDirectory]
///
/// ## Parameters
/// - `folderPath`: Name of the directory you want to serve from the *current folder*
///
/// - `defaultFile`: File name that will be served. *Default: index.html*
///
/// - `default404File`: File name that will be served for 404. *Default: 404.html*
///
/// - `showLogs`: Shows logs from the ShelfVirtualDirectory. *Default: true*
///
/// ## Examples
///
/// You can get router or handler or cascade from [ShelfVirtualDirectory]
/// instance
/// ```dart
///
/// final virDirRouter = ShelfVirtualDirectory(folderToServe);
///
/// final staticFileHandler = const Pipeline()
///     .addMiddleware(logRequests())
///     .addHandler(virDirRouter.handler);
///
/// io.serve(Cascade().add(staticFileHandler).handler,address,port).then((server){
///     print('Server is sunning at ${server.address}:${server.port}'),
/// });
///```
class ShelfVirtualDirectory {
  /// Absolute path to the directory
  final String folderPath;

  /// Default file to serve. Must be inside [folderPath].
  final String defaultFile;

  /// Default 404 file to serve. Must be inside [folderPath].
  final String default404File;

  /// Weather to list directory or not.
  final bool listDirectory;

  final FileHeaderParser _headersParser;
  final Directory _dir;

  /// Creates a instance of [ShelfVirtualDirectory]
  ///
  /// ## Parameters
  ///
  /// - `folderPath`: Name of the directory you want to serve. *Must be a absolute path*.
  /// - `defaultFile`: File name that will be serve. *Must be inside [folderPath]*
  /// - `default404File`: File name that will be served for 404. *Default: 404.html*
  /// - `listDirectory`: Lists files and directories from the [folderPath]
  /// - `headersParser`: Provide your own headers from the [File].
  ///
  /// ## Examples
  ///
  /// You can get router or handler or cascade from [ShelfVirtualDirectory]
  /// instance
  /// ```dart
  ///
  /// final virDirRouter = ShelfVirtualDirectory(folderToServe);
  ///
  /// final staticFileHandler = const Pipeline()
  ///     .addMiddleware(logRequests())
  ///     .addHandler(virDirRouter.handler);
  ///
  /// io.serve(Cascade().add(staticFileHandler).handler,address,port).then((server){
  ///     print('Server is sunning at ${server.address}:${server.port}'),
  /// });
  ///```
  ShelfVirtualDirectory(
    this.folderPath, {
    this.defaultFile = 'index.html',
    this.default404File = '404.html',
    this.listDirectory = true,
    FileHeaderParser headersParser = _defaultFileheaderPraser,
  })  : _dir = Directory(folderPath),
        _headersParser = headersParser {
    if (!_dir.existsSync()) {
      throw ArgumentError('A directory corresponding to folderpath '
          '"$folderPath" could not be found');
    }
  }

  /// Creates a instance of [Handler]
  Handler get handler => _handler;

  /// Returns a instance of [Router]
  ///
  /// Can be used to mount as a subroute
  ///
  /// ```
  /// final router = Router('/',ShelfVirtualDirectory('web').router);// localhost:8080/
  /// //or
  /// final router = Router('/home/',ShelfVirtualDirectory('web').router);//localhost:8080/home/
  /// ```
  Router get router => Router(notFoundHandler: _handler);

  /// Returns a instance of [Cascade]
  ///
  /// Can be used to directly serve from server
  /// ```
  /// import 'package:shelf/shelf_io.dart' as io show serve;
  ///
  /// final cascade = ShelfVirtualDirectory('web').cascade;
  /// io.serve(cascade,'localhost',8080).then((server){
  ///   print('Server is sunning at ${server.address}:${server.port}'),
  /// })
  ///
  /// ```
  Cascade get cascade => Cascade().add(_handler);

  Future<Response> _handler(Request req) async {
    if (!['GET', 'HEAD'].contains(req.method)) {
      return Response.notFound('Not Found');
    }

    final basePath = await _dir.resolveSymbolicLinks();

    // file system path for this entity
    final fsPath = path.joinAll([basePath, ...req.url.pathSegments]);

    // checks if index file should be served
    final fsPathType = await FileSystemEntity.type(fsPath);

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
        return Response(
          200,
          body: req.method == 'HEAD' ? null : indexFile.openRead(),
          headers: headers,
        );
      }
      return _handleDir(
        req,
        basePath,
        Directory(fsPath),
        _headersParser,
      );
    }

    switch (fsPathType) {
      case FileSystemEntityType.link:
        // todo: handle symboliclinks
        stdout
          ..write('[ShelfVirtualDirectory] ')
          ..write('Resolving symbolic link was not implemented ')
          ..write('Raise a issue at ')
          ..write('https://github.com/RatakondalaArun/')
          ..write('shelf_virtual_directory/issues/new')
          ..write('?title=Resolving%20Symbolic%20link%20failed\n');
        return _handleFile(req, basePath, null, _headersParser);
      case FileSystemEntityType.directory:
        return _handleDir(
          req,
          basePath,
          Directory(fsPath),
          _headersParser,
        );
      case FileSystemEntityType.file:
        return _handleFile(req, basePath, File(fsPath), _headersParser);
      default:
        return _handleFile(req, basePath, null, _headersParser);
    }
  }

  Future<Response> _handleFile(
    Request req,
    String fsPath,
    File? file,
    FileHeaderParser headerPraser,
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

    // check file permission of
    if (fileStat.modeString()[0] != 'r') return Response.forbidden('Forbidden');
    final length = fileStat.size;
    final range = req.headers[HttpHeaders.rangeHeader];
    final headers = await headerPraser(file) ?? {};

    if (range != null) {
      final matches = RegExp(r'^bytes=(\d*)\-(\d*)$').firstMatch(range);
      if (matches != null) {
        final startMatch = matches[1] ?? '';
        final endMatch = matches[2] ?? '';
        if (startMatch.isNotEmpty || endMatch.isNotEmpty) {
          int start;
          int end;
          if (startMatch.isEmpty) {
            start = length - int.parse(endMatch);
            if (start < 0) start = 0;
            end = length - 1;
          } else {
            start = int.parse(startMatch);
            end = endMatch.isEmpty ? length - 1 : int.parse(endMatch);
          }
          // If the range is syntactically invalid the Range header
          // MUST be ignored (RFC 2616 section 14.35.1).
          if (start <= end) {
            if (end >= length) {
              end = length - 1;
            }
            if (start >= length) {
              return Response(
                HttpStatus.requestedRangeNotSatisfiable,
                // headers: headers,
              );
            }

            // Override Content-Length with the actual bytes sent.
            headers[HttpHeaders.contentLengthHeader] =
                (end - start + 1).toString();

            // Set 'Partial Content' status code.
            headers[HttpHeaders.contentRangeHeader] =
                'bytes $start-$end/$length';
            // Pipe the 'range' of the file.

            return Response(
              HttpStatus.partialContent,
              body: req.method == 'HEAD' ? null : file.openRead(start, end + 1),
              headers: headers,
            );
          }
        }
      }
    }

    return Response(
      200,
      body: req.method == 'HEAD' ? null : file.openRead(),
      headers: headers,
    );
  }

  Future<Response> _handleDir(
    Request req,
    String fsPath,
    Directory dir,
    FileHeaderParser headerPraser,
  ) async {
    final requestedPath = req.url.path;
    if (!listDirectory) return Response.notFound('Not Found');
    if (!requestedPath.endsWith('/') && requestedPath.isNotEmpty) {
      return Response.movedPermanently('${req.requestedUri.toString()}/');
    }

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
      // sort entities
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
        add(_tr(entityName, requestedPath, entityStat));
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

// Parse header and return headers for the file
typedef FileHeaderParser = FutureOr<Map<String, Object>?> Function(File file);

Future<Map<String, Object>> _defaultFileheaderPraser(File file) async {
  final fileType = mime.lookupMimeType(file.path);

  // collect file data
  final fileStat = await file.stat();

  // check file permission
  if (fileStat.modeString()[0] != 'r') return {};

  return {
    HttpHeaders.contentTypeHeader: fileType ?? 'application/octet-stream',
    HttpHeaders.contentLengthHeader: fileStat.size.toString(),
    HttpHeaders.lastModifiedHeader: hp.formatHttpDate(fileStat.modified),
    HttpHeaders.acceptRangesHeader: 'bytes'
  };
}

/// Table row
String _tr(String name, String requestedPath, FileStat stat) {
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

// class RangeParser {
//   final String range;

//   final int _length;
//   final int? _start;
//   final int? _end;

//   int? get start => _start;
//   int? get end => _end;

//   String get contentLength => (_end - _start + 1).toString();

//   String get contentRange => 'bytes $_start-$_end/$_length';

//   RangeParser._(
//     this.range,
//     this._start,
//     this._end,
//     this._length,
//   );

//   Future<RangeParser?> parse(String header, File file) async {
//     final match = RegExp(r'^bytes=(\d*)\-(\d*)$').firstMatch(range);
//     if (match == null) return null;
//     final startMatch = match[1] ?? '';
//     final endMatch = match[2] ?? '';
//     final length = await file.length();
//     if (startMatch.isNotEmpty || endMatch.isNotEmpty) {
//       int start;
//       int end;
//       if (startMatch.isEmpty) {
//         start = length - int.parse(endMatch);
//         if (start < 0) start = 0;
//         end = length - 1;
//       } else {
//         start = int.parse(startMatch);
//         end = endMatch.isEmpty ? length - 1 : int.parse(endMatch);
//       }
//       if (start <= end) {
//         if (end >= length) {
//           end = length - 1;
//         }
//         if (start >= length) {
//           return null;
//         }
//       } else {
//         return null;
//       }
//       return RangeParser._(
//         header,
//         start,
//         end,
//         length,
//       );
//     }
//     return null;
//   }

//   Stream<List<int>> openRangeRead(File file) async* {
//     yield* file.openRead(_start, _end);
//   }

//   Response openRangeResponse(File file, [Map<String, Object>? headers]) {
//     print('object');
//     return Response(
//       206,
//       body: file.openRead(_start, _end),
//       headers: headers,
//     );
//   }
// }
