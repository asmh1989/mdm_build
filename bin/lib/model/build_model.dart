import 'package:meta/meta.dart';

import '../params/build_params.dart';

const propBuildId = 'build_id';
const propBuildTime = 'build_time';
const propCode = 'code';
const propMsg = 'msg';
const propParams = 'params';

class BuildModel {
  DateTime date = DateTime.now();

  final String build_id;

  BuildStatus status = BuildStatus.waiting;

  BuildParams params;

  int build_time;

  BuildModel({@required this.build_id, this.params, this.build_time = 0});

  BuildModel.fromJson(Map<String, dynamic> json)
      : build_id = json[propBuildId] {
    date = json['date'];
    build_time = json[build_time] ?? 0;
    date ??= DateTime.now();
    var info = json[propCode];
    if (info != null) {
      status = BuildStatus(info, json[propMsg]);
    } else {
      status = BuildStatus.waiting;
    }

    params = BuildParams.fromJson(json[propParams] ?? {});
  }

  Map<String, dynamic> toJson() {
    var data = <String, dynamic>{};
    data['date'] = date;
    data[propBuildId] = build_id;
    data[propCode] = status?.code;
    data[propMsg] = status?.msg;
    data[propBuildTime] = build_time ?? 0;
    data[propParams] = params?.toJson();
    return data;
  }
}

class BuildStatus {
  static final success = const BuildStatus(0, '打包成功');
  static final failed = const BuildStatus(1, '打包失败');
  static final waiting = const BuildStatus(2, '等待中');
  static final building = const BuildStatus(3, '编译中');
  static final illegal = const BuildStatus(-1, '非法id');

  final int code;

  final String msg;

  const BuildStatus(this.code, this.msg);

  BuildStatus.newFailed(String msg) : this(failed.code, msg);
}
