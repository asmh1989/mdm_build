import 'package:dio/dio.dart';
import 'lib/utils.dart';

class Weed {
  static const ip = 'android.justsafe.com';
  static const assignurl = 'http://$ip:9333/dir/assign';
  static const lookupurl = 'http://$ip:9333/dir/lookup?fileId=';
  static const authkey = 'Authorization';

  static Future<String> upload(String file) async {
    var dio = Dio();
    var res = await dio.get(assignurl);

    if (res.data != null) {
      Utils.log('获取fid成功 : ${res.data}');

      var auth = res.headers[authkey];
      var fid = res.data['fid'];
      var url = res.data['url'];

      res = await dio.post('http://$url/$fid',
          options: Options(headers: {authkey: auth}),
          data: FormData.fromMap({'file': await MultipartFile.fromFile(file)}));

      if (res.data != null) {
        Utils.log('上传成功 : ${res.data}');
        return fid;
      } else {
        throw '上传fid失败 : ${res.statusMessage}';
      }
    } else {
      throw '获取fid失败 : ${res.statusMessage}';
    }
  }
}