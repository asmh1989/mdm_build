import '../params/build_params.dart';

class BuildStatus {
  int code;

  String msg;

  BuildStatus({
    this.code,
    this.msg
  });

  BuildStatus.fromJson(Map<String, dynamic> json){
    code = json['code'];
    msg = json['msg'];
  }

  Map<String, dynamic> toJson(){
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['msg'] = this.msg;
    return data;
  }

  static BuildStatus newFailed(String msg) => new BuildStatus(code:1, msg: msg);

  static BuildStatus get SUCCESS => new BuildStatus(code:0, msg: '打包成功');
  static BuildStatus get FAILED => new BuildStatus(code:1, msg: '打包失败');
  static BuildStatus get WAITING => new BuildStatus(code:2, msg: '等待中');
  static BuildStatus get BUILDING => new BuildStatus(code:3, msg: '编译中');
  static BuildStatus get INIT => new BuildStatus(code:-1, msg: '初始化');
}


class BuildModel {

  DateTime date = new DateTime.now();

  String build_id;

  BuildStatus status = BuildStatus.INIT;

  String local_url='';

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
    var info = json['status'];
    if(info != null){
      status = BuildStatus.fromJson(info);
    } else {
      status = BuildStatus.INIT;
    }

    info = BuildParams.fromJson(json[params]);
    local_url  = json['local_url'];

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['date'] = this.date;
    data['build_id'] = this.build_id;
    data['status'] = this.status?.toJson();
    data['local_url'] = this.local_url;
    data['params'] = this.params?.toJson();
    return data;
  }
}