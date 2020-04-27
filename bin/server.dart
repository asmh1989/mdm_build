import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:common_utils/common_utils.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

import 'lib/build.dart';
import 'lib/db.dart';
import 'lib/download.dart';
import 'lib/params/build_params.dart';
import 'lib/utils.dart';

void main(List<String> args) async {
  var parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '7002')
    ..addOption('sql', abbr: 's', defaultsTo: '127.0.0.1:27017');

  var result = parser.parse(args);

  var port = int.tryParse(result['port']);
  var ip = result['sql'];

  if (port == null) {
    stdout.writeln(
        'Could not parse port value "${result['port']}" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }

  /// 数据库连接
  DBManager.connect(ip: ip);

  /// 编译框架初始化
  await Build.init();

  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest);

  var server = await io.serve(handler, '0.0.0.0', port);
  Utils.log('Serving at http://${server.address.host}:${server.port}');
}

FutureOr<shelf.Response> ok(FutureOr<String> content) {
  return shelf.Response.ok(content,
      headers: {'Content-Type': 'application/json'});
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
      var params = {};

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
      } catch (e) {
        Utils.log('error : ' + e);
      }

      var data = await Build.getBuilds(
          status: params['status'],
          page: params['page'],
          pageSize: params['pageSize']);

      return ok(Utils.ok({'data': data}));
    } else if (request.url.path == 'app/count') {
      int status;
      if (request.url.query != null && request.url.query.isNotEmpty) {
        try {
          status = int.parse(request.url.query.split('=').last);
        } catch (e) {
          Utils.log('error : ' + e);
        }
      }

      return ok(Utils.ok({'data': await Build.getCount(status)}));
    } else if (request.url.path.startsWith('app/query/')) {
      var data = await Build.getBuild(request.url.pathSegments.last);
      return ok(json.encode(data ?? {}));
    } else if (request.url.path.startsWith('app/package/')) {
      return await downloadStaticFile(request);
    } else if (request.url.path.startsWith('app/rebuild/')) {
      var result = await Build.rebuild(request.url.pathSegments.last);
      return ok(result ? 'ok' : 'error');
    } else {
      return shelf.Response.forbidden('forbidden for "${request.url}"');
    }
  } else if (request.method == 'POST') {
    try {
      Map body = json.decode(await request.readAsString());

      /// 打包请求
      if (request.url.path == 'app/build') {
        var params = BuildParams.fromJson(body);

        var key = await Build.start(params);

//        Utils.log('body : ${json.encode(params.toJson())}');
        return ok(Utils.ok({'id': key}));
      } else if (request.url.path == 'config/sun') {
        return ok(Utils.ok({'env': await Build.initConfig(body)}));
      } else if (request.url.path == 'test/email') {
        var id = body['id'];
        var email = body['email'];
        if (id == null || !RegexUtil.isEmail(email)) {
          return ok(Utils.error({'msg': '参数错误'}));
        }
        return ok(Utils.ok({'msg': await Build.testEmail(id, email)}));
      }
    } catch (e) {
      Utils.log(e.toString());
      return ok(Utils.error({'msg': e.toString()}));
    }

    return shelf.Response.forbidden('forbidden for "${request.url}"');
  } else {
    return ok('Request for "${request.url}"');
  }
}
