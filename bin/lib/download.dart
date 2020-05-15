import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart' show Response, Request;

import '../weed.dart';
import 'constant.dart';
import 'db.dart';
import 'model/build_model.dart';
import 'utils.dart';

final _defaultMimeTypeResolver = MimeTypeResolver();

FutureOr<Response> downloadStaticFile(Request request) async {
  var contentTypeResolver = _defaultMimeTypeResolver;

  var build_id = request.url.pathSegments.last;

  if (build_id.isNotEmpty && build_id.contains('.')) {}

  var data = await DBManager.findOne(
      Constant.tableBuild,
      where.eq(propBuildId,
          build_id.contains('.') ? build_id.split('.')[0] : build_id));
  if (data != null) {
    var model = BuildModel.fromJson(data);
    if (model.fid.isNotEmpty) {
      var url = 'http://${Weed.ip}:8080/${model.fid}';
      Utils.log('发现fid, 重定向到 $url');
      return Response.seeOther(url);
    }
  }

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
