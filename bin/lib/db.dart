import 'package:mongo_dart/mongo_dart.dart' ;
import 'utils.dart';
/// 数据库操作
class DBManager {
  static Db _db;

  static void connect() async{
    if(_db == null || _db.state != State.OPEN ){
      _db = new Db('mongodb://127.0.0.1:27017/builder');
      await _db.open();
    }
  }

  static Map<String, dynamic> updateDate(Map<String, dynamic> data){
    data['date'] = new DateTime.now();
    return  data;
  }

  static void save(String collection, {String id, Map<String, dynamic> data}) async {

    try {
      await connect();

      var coll = _db.collection(collection);

      Map<String, dynamic> val;

      if(id == null){
        val = await coll.findOne();
      } else {
        val = await coll.findOne(where.eq(id, data[id]));
      }

      if (val != null && val.isNotEmpty) {
        for (String key in data.keys) {
          val[key] = data[key];
        }
        await coll.save(updateDate(val));
      } else {
        await coll.insert(updateDate(data));
      }
    } catch (e){
      Utils.log(e.toString());
    }
  }

  static Future<Stream<Map<String, dynamic>>> find(String collection, [selector]) async {
    await connect();
    var coll = _db.collection(collection);

    return await coll.find(selector);
  }

  static Future<Map<String, dynamic>> findOne(String collection, [selector]) async {
    await connect();
    var coll = _db.collection(collection);

    return await coll.findOne(selector);
  }

  static Future<int> count(String collection, [selector]) async {
    await connect();
    var coll = _db.collection(collection);
    return coll.count(selector);
  }

}