import 'dart:async';
import 'dart:io';
import 'dart:core';
import 'package:shelf/shelf.dart' show Response, Request;

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'utils.dart';

final _defaultMimeTypeResolver = new MimeTypeResolver();

DateTime toSecondResolution(DateTime dt) {
  if (dt.millisecond == 0) return dt;
  return dt.subtract(new Duration(milliseconds: dt.millisecond));
}

FutureOr<Response> downloadStaticFile(Request request) async {
  MimeTypeResolver contentTypeResolver = _defaultMimeTypeResolver;

  var build_id = request.url.pathSegments.last;

  var fsPath = Utils.packagePath(build_id);

  var entityType = FileSystemEntity.typeSync(fsPath, followLinks: true);

  File file;

  if (entityType == FileSystemEntityType.file) {
    file = new File(fsPath);
  }

  if (file == null) {
    return new Response.notFound('Not Found');
  }

  return _handleFile(request, file, () async {
    return contentTypeResolver.lookup(file.path);
  }, build_id);
}

Future<Response> _handleFile(
    Request request, File file, FutureOr<String> getContentType(),
    [String fileName]) async {
  var stat = file.statSync();
  var ifModifiedSince = request.ifModifiedSince;

  if (ifModifiedSince != null) {
    var fileChangeAtSecResolution = toSecondResolution(stat.changed);
    if (!fileChangeAtSecResolution.isAfter(ifModifiedSince)) {
      return new Response.notModified();
    }
  }

  var headers = {
    HttpHeaders.contentLengthHeader: stat.size.toString(),
    HttpHeaders.lastModifiedHeader: formatHttpDate(stat.changed),
  };

  var contentType = await getContentType();
  if (contentType != null) headers[HttpHeaders.contentTypeHeader] = contentType;

  return new Response.ok(file.openRead(), headers: headers);
}
