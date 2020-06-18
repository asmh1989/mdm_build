import 'dart:convert';
import 'dart:io' show Platform, Directory;

import 'package:common_utils/common_utils.dart';
import 'package:dio/dio.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shell/shell.dart';
import 'package:uuid/uuid.dart';

import 'model/build_model.dart';
import 'model/config_model.dart';
import 'weed.dart';

class Utils {
  static final Uuid _uuid = Uuid();

  static final Dio _dio = Dio();

  static String ip;
  static int port;

  /// true: 表示主服务器, false: 表示服务只会根据redis订阅打包任务
  static bool isManager = false;

  /// true: 表示不会上传到 weed
  static bool disableWeed = false;

  /// 主服务下, 关闭打包能力
  static bool disableManagerBuild = false;

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

  static Map<String, dynamic> queryResult(BuildModel model) {
    return {
      'status': model.status.code,
      'msg': model.status.code == BuildStatus.failed.code
          ? BuildStatus.failed.msg
          : model.status.msg,
      'detail': model.status.msg,
      'downloadPath': model.status.code == BuildStatus.success.code
          ? '/app/package/${model.build_id}.apk'
          : ''
    };
  }

  static void mail({BuildModel model, String mail}) async {
    var url = model.params.responseUrl;
    if (url.isNotEmpty && RegexUtil.isURL(url)) {
      try {
        var res = await _dio.post(url, data: queryResult(model));
        if (res.data != null) {
          log('${model.build_id} 回传成功... ${res.data}');
        } else {
          throw '${res.statusMessage}';
        }
      } catch (e) {
        log('${model.build_id}  回传失败... $e');
      }
    }

    if (mail.isEmpty || !RegexUtil.isEmail(mail)) {
      if (mail.isNotEmpty) {
        log('$mail 邮箱不正确');
      }
      return;
    }
    var id = model.build_id;
    var content = '';
    var title = '打包通知: 恭喜 ${id} 打包成功了!!';
    if (model.status.code == BuildStatus.failed.code) {
      title = '打包通知: 抱歉 ${id} 打包失败了..';

      content = '''
<p> 打包结果如下:  </p>
<ul>
<li>打包任务: <code>${id}</code></li>
<li>打包时间: <code>${model.date}</code></li>
<li>打包结果: <code>失败</code></li>
<li>失败原因: </li>
</ul>
<pre><code>${model.status.msg}</code></pre>
<ul>
</ul>

<p>-----------------------------------------</p>
<p>PowerBy <code>$ip</code></p>
    ''';
    } else if (model.status.code == BuildStatus.success.code) {
      var map = model.params.version.toJson();
      map.removeWhere((key, value) {
        return value == null || value.toString().isEmpty;
      });

      if (model.params.configs.baseConfig.assets_config.isNotEmpty) {
        map['assets_config'] = model.params.configs.baseConfig.assets_config;
      }

      content = '''
<h3> 打包结果如下:  </h3>
<ul>
<li>打包任务: <code>${id}</code></li>
<li>打包时间: <code>${model.date}</code></li>
<li>打包结果: <code>成功</code></li>
<li>打包耗时: <code>${model.build_time} 秒</code></li>
<li>点击下载: <a href="http://${Weed.ip}:8080/${model.fid}" target="_blank"> 点我! </a></li>
<li>版本信息: </li>
</ul>
<ul>
<pre><code>${JsonEncoder.withIndent('    ').convert(map)}</code></pre>
</ul>

--------------------------------------------
<p>PowerBy <code>$ip</code></p>
    ''';
    } else {
      log('${model.status} 非法状态');
      return;
    }

    _sendMail(content, title, mail);
  }

  static void _sendMail(String content, String title, String mail) async {
    var username = 'androidbuild@justsafe.com';
    var password = 'Justsy123';

    final server = SmtpServer('mail.justsafe.com',
        username: username,
        password: password,
        port: 587,
        ignoreBadCertificate: true);

    final message = Message()
      ..from = Address(username, 'androidBuild')
      ..recipients.add(mail)
      ..subject = title
      ..html = content;

    try {
      await send(message, server);
      Utils.log('Message sent: $mail');
    } on MailerException catch (e) {
      Utils.log('Message not sent. $e');
    }
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
