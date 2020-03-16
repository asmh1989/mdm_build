import 'dart:convert';
import 'dart:io' show Platform, Directory;

import 'package:dio/dio.dart';
import 'package:shell/shell.dart';
import 'package:uuid/uuid.dart';

import 'model/config_model.dart';

class Utils {
  static final Uuid _uuid = Uuid();

  static final Dio _dio = Dio();

  static String get cachePath => envConfig.cache_home;

  static String get HOME =>
      '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}';

  static String appPath(String build_id) {
    var dir = Directory('$cachePath/apps/$build_id');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  static Future<void> clone(
      {String url,
      String branch,
      String path,
      String name,
      String commitId}) async {
    try {
      log('start git clone ... $url to ${path ?? ''}/$name');

      var shell = Shell(workingDirectory: path ?? HOME);

      var list = ['clone', url];
      if (branch != null && branch.isNotEmpty) {
        list.add('-b');
        list.add(branch);
      }

      if (name != null) {
        list.add(name);
        await shell.run('rm', ['-rf', name]);
      }

      log('shell : git ${list.toString()}');

      var result = await shell.run('git', list);

      log('git clone ${url}, done  ${result.exitCode}, ${result.stderr}');
      if (result.exitCode != 0) {
        throw result.stderr;
      } else {
        if (commitId != null && commitId.isNotEmpty) {
          list.clear();
          list.add('checkout');
          list.add(commitId);

          var shell = Shell(workingDirectory: name);

          result = await shell.run('git', list);
          if (result.exitCode != 0) {
            throw result.stderr;
          }
        }
      }
    } catch (e) {
      log(e);
      throw '${url} git clone 失败';
    }
  }

  static Future<void> download(String url, String path) async {
    try {
      log('start download... $url to $path');
      await _dio.download(url, path);
      log('$url downloaded');
    } catch (e) {
      log(e);
      throw '${url} 下载失败';
    }
  }

  static String error(Map res) {
    return json.encode({'error': res}, toEncodable: myEncode);
  }

  static void log(var msg) {
    print('${DateTime.now().toIso8601String()} ${msg.toString()}');
  }

  static String logPath(String build_id) {
    if (!Directory('$cachePath/logs').existsSync()) {
      Directory('$cachePath/logs').createSync(recursive: true);
    }
    return '$cachePath/logs/$build_id.log';
  }

  static dynamic myEncode(dynamic item) {
    if (item is DateTime) {
      return item.toIso8601String();
    }
    return item;
  }

  static String newKey() {
    return _uuid.v1();
  }

  static String ok(Map res) {
    return json.encode({'ok': res}, toEncodable: myEncode);
  }

  static String packagePath(String build_id) {
    if (!Directory('$cachePath/packages').existsSync()) {
      Directory('$cachePath/packages').createSync(recursive: true);
    }
    return '$cachePath/packages/$build_id';
  }

  static Future svnCheckout({String url, String version, String path}) async {
    try {
      log('start svn co  ... $url:$version to $path');

      var shell = Shell(workingDirectory: path);

      var command =
          'co $url $path --username zhangjz --password zhangjz123abc --no-auth-cache --non-interactive';

      if (version != null) {
        command += ' -r $version';
      }

      var commands = command.split(' ');

      var result = await shell.run('svn', commands);

      log('svn co ${url}, done  ${result.exitCode}, ${result.stderr}');

      if (result.exitCode != 0) {
        throw result.stderr;
      }
    } catch (e) {
      log(e);
      if (e is String) {
        rethrow;
      } else {
        throw '${url} svn checkout 失败';
      }
    }
  }
}
