import 'dart:io';
import 'package:shell/shell.dart';

import 'utils.dart';
import 'model/config_model.dart';

class Shell2 {
  Shell _shell;
  File _file;
  final String workDir;
  final Map<String, String> env;
  Shell2({this.workDir, this.env}) {
    Map<String, String> config_env = envConfig.toJson2();
    config_env.addAll(env ?? {});
    _shell = new Shell(workingDirectory: workDir, environment: config_env);
  }

  Future run(String command, [String dir]) async {
    if (dir != null) {
      _shell.navigate(dir);
    }

    if (_file == null) {
      String path = Utils.cachePath + '/tmp/' + Utils.newKey() + '.sh';
      _file = new File(path);
    }

    if (_file.existsSync()) {
      _file.deleteSync();
    }

    _file.createSync(recursive: true);

    await _file.writeAsString(command);

//    Utils.log('sh_file: ${_file.path}');
    var result = await _shell.run('sh', ['${_file.path}']);

    await _file.delete();

    return result;
  }
}
