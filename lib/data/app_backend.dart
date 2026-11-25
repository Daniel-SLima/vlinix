import 'package:supabase_flutter/supabase_flutter.dart';
import 'demo_store.dart';

/// Production keeps its existing Supabase connection. The public demo never
/// initializes that connection and uses the same screens with local data.
class AppBackend {
  static const bool isDemo = bool.fromEnvironment('DEMO_MODE');
  static final DemoStore demo = DemoStore();

  static dynamic get client => isDemo ? demo : Supabase.instance.client;
}
