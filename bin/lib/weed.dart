import 'package:dio/dio.dart';

import 'utils.dart';

class Weed {
  static const ip = 'android.justsafe.com';
  static const assignUrl = 'http://$ip:9333/dir/assign';
  static const lookupUrl = 'http://$ip:9333/dir/lookup?fileId=';
  static const authKey = 'Authorization';

  static Future<String> upload(String file, {String fileName}) async {
    var dio = Dio();
    var res = await dio.get(assignUrl);

    if (res.data != null) {
      Utils.log('获取fid成功 : ${res.data}');

      var auth = res.headers[authKey];
      var fid = res.data['fid'];
      var url = res.data['url'];

      res = await dio.post('http://$url/$fid',
          options: Options(headers: {authKey: auth}),
          data: FormData.fromMap({
            'file': await MultipartFile.fromFile(file, filename: fileName)
          }));

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
