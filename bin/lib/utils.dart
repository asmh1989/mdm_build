import 'dart:io' show Platform, Directory;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:shell/shell.dart';

import 'model/config_model.dart';

class Utils {
  static Uuid _uuid = new Uuid();

  static Dio _dio = new Dio();

  static String get HOME =>
      '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}';

  static String get cachePath => envConfig.cache_home;

  static String newKey() {
    return _uuid.v1();
  }

  static String packagePath(String build_id) {
    if (!Directory('$cachePath/packages').existsSync()) {
      Directory('$cachePath/packages').createSync(recursive: true);
    }
    return '$cachePath/packages/$build_id';
  }

  static String logPath(String build_id) {
    if (!Directory('$cachePath/logs').existsSync()) {
      Directory('$cachePath/logs').createSync(recursive: true);
    }
    return '$cachePath/logs/$build_id.log';
  }

  static String appPath(String build_id) {
    Directory dir = Directory('$cachePath/apps/$build_id');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  static Future<void> download(String url, String path) async {
    try {
      log('start download... $url to $path');
      await _dio.download(url, path);
      log('$url downloaded');
    } catch (e) {
      log(e);
      throw new Exception('${url} 下载失败');
    }
  }

  static Future<void> clone(
      {String url, String branch, String path, String name}) async {
    try {
      log('start git clone ... $url to ${path ?? ''}/$name');

      var shell = new Shell(workingDirectory: path ?? HOME);

      var list = ['clone', url];
      if (branch != null) {
        list.add('-b');
        list.add(branch);
      }

      if (name != null) {
        list.add(name);
      }

      var result = await shell.run('git', list);

      log('git clone ${url}, done  ${result.exitCode}, ${result.stderr}');
      if (result.exitCode != 0) {
        throw new Exception('');
      }
    } catch (e) {
      log(e);
      throw new Exception('${url} git clone 失败');
    }
  }

  static Future svnCheckout({String url, int version, String path}) async {
    try {
      log('start svn co  ... $url:$version to $path');

      var shell = new Shell(workingDirectory: path);

      String command =
          'co $url $path --username sunmh --password Justsy123 --no-auth-cache --non-interactive';

      if (version != null) {
        command += ' -r $version';
      }

      List<String> commands = command.split(' ');

      var result = await shell.run('svn', commands);

      log('svn co ${url}, done  ${result.exitCode}, ${result.stderr}');

      if (result.exitCode != 0) {
        throw new Exception('');
      }
    } catch (e) {
      log(e);
      throw new Exception('${url} svn checkout 失败');
    }
  }

  static dynamic myEncode(dynamic item) {
    if (item is DateTime) {
      return item.toIso8601String();
    }
    return item;
  }

  static String ok(Map res) {
    return json.encode({'ok': res}, toEncodable: myEncode);
  }

  static String error(Map res) {
    return json.encode({'error': res}, toEncodable: myEncode);
  }

  static void log(var msg) {
    print('${DateTime.now().toIso8601String()} ${msg.toString()}');
  }
}
