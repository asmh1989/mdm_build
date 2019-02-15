import 'dart:io' show Platform;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:shell/shell.dart';


class Utils {
  static Uuid _uuid = new Uuid();

  static Dio _dio = new Dio();

  static String get cachePath => '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/.mdm_build';

  static String newKey(){
    return _uuid.v1();
  }

  static Future<void> download(String url, String path) async {
    try {
      print('start download... $url to $path');
      await _dio.download(url, path);
      print('$url downloaded');
    } catch (e){
      print(e);
      throw new Exception('${url} 下载失败');
    }
  }

  static Future<void> clone({String url, String branch, String path,  String name}) async {

    try{
      print('start git clone ... $url to $path');

      var shell = new Shell(workingDirectory: path);

      var result = await shell.run('git', ['clone', url, '-b', branch, name]);

      print('git clone ${url}, done  ${result.exitCode}, ${result.stderr}');

    } catch (e) {
      print(e);
      throw new Exception('${url} git clone 失败');
    }

  }

  static String ok(Map res){
    return json.encode({'ok': res});
  }

  static String error(Map res){
    return json.encode({'error': res});
  }
}