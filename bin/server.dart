import 'dart:io';

import 'dart:async';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

import 'lib/params/build_params.dart';
import 'lib/db.dart';
import 'lib/build.dart';
import 'lib/utils.dart';
import 'lib/download.dart';

main(List<String> args) async {
  var parser = ArgParser()..addOption('port', abbr: 'p', defaultsTo: '7001');

  var result = parser.parse(args);

  var port = int.tryParse(result['port']);

  if (port == null) {
    stdout.writeln(
        'Could not parse port value "${result['port']}" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }

  /// 数据库连接
  DBManager.connect();

  /// 编译框架初始化
  await Build.init();

  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest);

  var server = await io.serve(handler, '0.0.0.0', port);
  Utils.log('Serving at http://${server.address.host}:${server.port}');
}

FutureOr<shelf.Response> _echoRequest(shelf.Request request) async {
  var connectionInfo =
      request.context['shelf.io.connection_info'] as HttpConnectionInfo;

  var ip = connectionInfo.remoteAddress.address;

  if (!Build.isWhiteIp(ip)) {
    return shelf.Response.forbidden('forbidden for "${request.url}"');
  }

  if (request.method == 'GET') {
    if (request.url.path == 'app/query') {
      Map<String, dynamic> params = {};

      try {
        if (request.url.query != null && request.url.query.isNotEmpty) {
          var list = request.url.query.split('&');
          for (var d in list) {
            if (d.contains('=')) {
              var l = d.split('=');
              params[l[0]] = int.parse(l[1]);
            }
          }
        }
      } catch (e) {}

      var data = await Build.getBuilds(
          status: params['status'],
          page: params['page'],
          pageSize: params['pageSize']);

      return shelf.Response.ok(Utils.ok({'data': data}));
    } else if (request.url.path == 'app/count') {
      var status;
      if (request.url.query != null && request.url.query.isNotEmpty) {
        try {
          status = int.parse(request.url.query.split('=').last);
        } catch (e) {}
      }

      return shelf.Response.ok(
          Utils.ok({'data': await Build.getCount(status)}));
    } else if (request.url.path.startsWith('app/query/')) {
      var data = await Build.getBuild(request.url.pathSegments.last);
      if (data != null) {
        return shelf.Response.ok(Utils.ok({'data': data}));
      } else {
        return shelf.Response.ok(Utils.error({'msg': '非法id'}));
      }
    } else if (request.url.path.startsWith('app/package/')) {
      return await downloadStaticFile(request);
    } else {
      return shelf.Response.forbidden('forbidden for "${request.url}"');
    }
  } else if (request.method == 'POST') {
    try {
      Map body = json.decode(await request.readAsString());

      /// 打包请求
      if (request.url.path == 'app/build') {
        BuildParams params = BuildParams.fromJson(body);

        String key = await Build.start(params);

//        Utils.log('body : ${json.encode(params.toJson())}');
        return shelf.Response.ok(Utils.ok({'id': key}));
      } else if (request.url.path == 'config/sun') {
        return shelf.Response.ok(
            Utils.ok({'env': await Build.initConfig(body)}));
      }
    } catch (e) {
      Utils.log(e.toString());
      return shelf.Response.ok(Utils.error({'msg': e.toString()}));
    }

    return shelf.Response.forbidden('forbidden for "${request.url}"');
  } else {
    return shelf.Response.ok('Request for "${request.url}"');
  }
}
