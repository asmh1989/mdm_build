import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart' show Response, Request;

import 'utils.dart';

final _defaultMimeTypeResolver = MimeTypeResolver();

FutureOr<Response> downloadStaticFile(Request request) async {
  var contentTypeResolver = _defaultMimeTypeResolver;

  var build_id = request.url.pathSegments.last;

  var fsPath = Utils.packagePath(build_id);

  var entityType = FileSystemEntity.typeSync(fsPath, followLinks: true);

  File file;

  if (entityType == FileSystemEntityType.file) {
    file = File(fsPath);
  }

  if (file == null) {
    return Response.notFound('Not Found');
  }

  return _handleFile(request, file, () async {
    return contentTypeResolver.lookup(file.path);
  }, build_id);
}

DateTime toSecondResolution(DateTime dt) {
  if (dt.millisecond == 0) return dt;
  return dt.subtract(Duration(milliseconds: dt.millisecond));
}

Future<Response> _handleFile(
    Request request, File file, FutureOr<String> Function() getContentType,
    [String fileName]) async {
  var stat = file.statSync();
  var ifModifiedSince = request.ifModifiedSince;

  if (ifModifiedSince != null) {
    var fileChangeAtSecResolution = toSecondResolution(stat.changed);
    if (!fileChangeAtSecResolution.isAfter(ifModifiedSince)) {
      return Response.notModified();
    }
  }

  var headers = {
    HttpHeaders.contentLengthHeader: stat.size.toString(),
    HttpHeaders.lastModifiedHeader: formatHttpDate(stat.changed),
  };

  var contentType = await getContentType();
  if (contentType != null) headers[HttpHeaders.contentTypeHeader] = contentType;

  return Response.ok(file.openRead(), headers: headers);
}
