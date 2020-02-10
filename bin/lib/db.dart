import 'package:mongo_dart/mongo_dart.dart';

import 'utils.dart';

/// 数据库操作
class DBManager {
  static Db _db;

  static void connect() async {
    if (_db == null || _db.state != State.OPEN) {
      _db = Db('mongodb://127.0.0.1:27017/build_data');
      await _db.open();
    }
  }

  static Future<int> count(String collection, [selector]) async {
    try {
      await connect();
      var coll = _db.collection(collection);
      return coll.count(selector);
    } catch (e) {
      _db = null;
      return -1;
    }
  }

  static Future<Stream<Map<String, dynamic>>> find(String collection,
      [selector]) async {
    try {
      await connect();
      var coll = _db.collection(collection);

      return await coll.find(selector);
    } catch (e) {
      _db = null;
      return null;
    }
  }

  static Future<Map<String, dynamic>> findOne(String collection,
      [selector]) async {
    try {
      await connect();
      var coll = _db.collection(collection);

      return await coll.findOne(selector);
    } catch (e) {
      _db = null;
      return null;
    }
  }

  static void save(String collection,
      {String id, Map<String, dynamic> data}) async {
    try {
      await connect();

      var coll = _db.collection(collection);

      Map<String, dynamic> val;

      if (id == null) {
        val = await coll.findOne();
      } else {
        val = await coll.findOne(where.eq(id, data[id]));
      }

      if (val != null && val.isNotEmpty) {
        for (var key in data.keys) {
          val[key] = data[key];
        }
        await coll.save(_updateDate(val));
      } else {
        await coll.insert(_updateDate(data));
      }
    } catch (e) {
      _db = null;
      Utils.log(e.toString());
    }
  }

  static Map<String, dynamic> _updateDate(Map<String, dynamic> data) {
    data['date'] = DateTime.now();
    return data;
  }
}
