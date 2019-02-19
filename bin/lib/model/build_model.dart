import '../params/build_params.dart';

const PROP_BUILD_ID = 'build_id';
const PROP_CODE = 'code';
const PROP_MSG = 'msg';
const PROP_PARAMS = 'params';

class BuildStatus {
  int code;

  String msg;

  BuildStatus({
    this.code,
    this.msg
  });

  static BuildStatus newFailed(String msg) => new BuildStatus(code:1, msg: msg);

  static BuildStatus get SUCCESS => new BuildStatus(code:0, msg: '打包成功');
  static BuildStatus get FAILED => new BuildStatus(code:1, msg: '打包失败');
  static BuildStatus get WAITING => new BuildStatus(code:2, msg: '等待中');
  static BuildStatus get BUILDING => new BuildStatus(code:3, msg: '编译中');
}


class BuildModel {

  DateTime date = new DateTime.now();

  String build_id;

  BuildStatus status = BuildStatus.WAITING;


  BuildParams params;


  BuildModel({
    this.build_id,
    this.params
  });

  BuildModel.fromJson(Map<String, dynamic> json) {
    date = json['date'];
    if(date == null){
        date = DateTime.now();
    }
    build_id = json[PROP_BUILD_ID];
    var info = json[PROP_CODE];
    if(info != null){
      status = BuildStatus(code: info, msg: json[PROP_MSG]);
    } else {
      status = BuildStatus.WAITING;
    }

    params = BuildParams.fromJson(json[PROP_PARAMS]??{});
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['date'] = this.date;
    data[PROP_BUILD_ID] = this.build_id;
    data[PROP_CODE] = this.status?.code;
    data[PROP_MSG] = this.status?.msg;

    data[PROP_PARAMS] = this.params?.toJson();
    return data;
  }
}