import '../params/build_params.dart';

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

  String local_url='';

  String local_path='';

  BuildParams params;


  BuildModel({
    this.build_id,
    this.local_url = '',
    this.params
  });

  BuildModel.fromJson(Map<String, dynamic> json) {
    date = json['date'];
    if(date == null){
        date = DateTime.now();
    }
    build_id = json['build_id'];
    var info = json['code'];
    if(info != null){
      status = BuildStatus(code: info, msg: json['msg']);
    } else {
      status = BuildStatus.WAITING;
    }

    info = BuildParams.fromJson(json[params]);
    local_url  = json['local_url'];
    local_path = json['local_path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['date'] = this.date;
    data['build_id'] = this.build_id;
    data['code'] = this.status?.code;
    data['msg'] = this.status?.msg;

    data['local_url'] = this.local_url;
    data['params'] = this.params?.toJson();
    data['local_path'] = this.local_path;
    return data;
  }
}