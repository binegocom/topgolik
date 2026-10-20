import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStore {
  static const _key = 'topgolik.favorite.match.ids.v1';
  Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? <String>[])
        .map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> save(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.map((v) => v.toString()).toList()..sort());
  }
}
