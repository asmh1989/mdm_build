import '../params/build_params.dart';

const propBuildId = 'build_id';
const propCode = 'code';
const propMsg = 'msg';
const propParams = 'params';
const propBuildTime = 'build_time';

class BuildStatus {
  int code;

  String msg;

  BuildStatus({this.code, this.msg});

  static BuildStatus newFailed(String msg) =>
      new BuildStatus(code: failed.code, msg: msg);

  static final BuildStatus success = BuildStatus(code: 0, msg: '打包成功');
  static final BuildStatus failed = BuildStatus(code: 1, msg: '打包失败');
  static final BuildStatus waiting = BuildStatus(code: 2, msg: '等待中');
  static final BuildStatus building = BuildStatus(code: 3, msg: '编译中');
}

class BuildModel {
  DateTime date = new DateTime.now();

  String build_id;

  BuildStatus status = BuildStatus.waiting;

  BuildParams params;

  int build_time;

  BuildModel({this.build_id, this.params, this.build_time = 0});

  BuildModel.fromJson(Map<String, dynamic> json) {
    date = json['date'];
    build_time = json[build_time] ?? 0;
    if (date == null) {
      date = DateTime.now();
    }
    build_id = json[propBuildId];
    var info = json[propCode];
    if (info != null) {
      status = BuildStatus(code: info, msg: json[propMsg]);
    } else {
      status = BuildStatus.waiting;
    }

    params = BuildParams.fromJson(json[propParams] ?? {});
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['date'] = this.date;
    data[propBuildId] = this.build_id;
    data[propCode] = this.status?.code;
    data[propMsg] = this.status?.msg;
    data[propBuildTime] = this.build_time ?? 0;
    data[propParams] = this.params?.toJson();
    return data;
  }
}
