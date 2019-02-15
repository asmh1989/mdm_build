import 'package:mongo_dart/mongo_dart.dart' ;

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

  static void save(String collection, String id, Map<String, dynamic> data) async {
    await connect();

    var coll = _db.collection(collection);

    Map<String, dynamic> val = await coll.findOne(where.eq(id, data[id]));

    if(val != null && val.isNotEmpty){
      for(String key in data.keys){
        val[key] = data[key];
      }
      await coll.save(updateDate(val));
    } else {
      await coll.insert(updateDate(data));
    }
  }
}