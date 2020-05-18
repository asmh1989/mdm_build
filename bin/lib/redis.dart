import 'package:dartis/dartis.dart';

import './utils.dart';

typedef OnReceiver = void Function(String key, String value);

class Redis {
  static const _url = 'redis://192.168.10.64:6379';

  /// 12分钟的超时时间
  static const _expire = 60 * 12;

  static Client _client;

  static final String _value = Utils.newKey();

  static Commands<String, String> _commands;

  static PubSub<String, String> sub;

  static OnReceiver _receiver;

  static void connect() async {
    if (_client == null) {
      _client = await Client.connect(_url);
      sub = await PubSub.connect<String, String>(_url);
      _commands = _client.asCommands<String, String>();

      sub.stream.listen((PubSubEvent e) {
        if (_receiver != null) {
          if (e is MessageEvent<String, String>) {
            _receiver(e.channel, e.message);
          }
        }
      });
    }
  }

  static void setReceiver(OnReceiver receiver) {
    if (receiver != null) {
      _receiver = receiver;
    }
  }

  static void _disconnect() async {
    if (_client != null) {
      try {
        await _client.disconnect();
        // ignore: empty_catches
      } catch (e) {}
      _client = null;
    }
  }

  static void init() async {
    await connect();
  }

  static Future<bool> lock(String key) async {
    try {
      await connect();

      final result = await _commands
          .eval<int>('''if (redis.call('setnx',KEYS[1],ARGV[1]) < 1) then
          return 0; end;
          redis.call('expire',KEYS[1],tonumber(ARGV[2]));
          return 1;
         ''', keys: [key], args: [_value, _expire]);

      Utils.log(' lock $key  result = ${result == 1}');

      return result == 1;
    } catch (e) {
      Utils.log(' lock $key  error = $e');

      await _disconnect();
      return false;
    }
  }

  static Future<bool> unlock(String key) async {
    try {
      await connect();

      var script = '''if redis.call('get', KEYS[1]) == ARGV[1] then 
          return redis.call('del', KEYS[1]) 
          else 
          return 0 
          end''';

      final result =
          await _commands.eval<int>(script, keys: [key], args: [_value]);
      Utils.log(' unlock $key  result = ${result == 1}');

      return result == 1;
    } catch (e) {
      Utils.log(' unlock $key  error = $e');
      _disconnect();
      return false;
    }
  }

  static void publish(String channel, String message) async {
    try {
      await connect();
      await _commands.publish(channel, message);
    } catch (e) {
      Utils.log(' publish $channel  error = $e');
      _disconnect();
    }
  }

  static void subscribe(String channel) async {
    try {
      await connect();
      sub.subscribe(channel: channel);
    } catch (e) {
      Utils.log(' subscribe $channel  error = $e');
      _disconnect();
    }
  }
}
