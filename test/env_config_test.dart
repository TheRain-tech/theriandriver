import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/config/env_config.dart';

void main() {
  tearDown(dotenv.clean);

  test('server calls have a production address without a bundled env asset', () {
    dotenv.clean();
    expect(
      EnvConfig.apiBaseUrl,
      'https://node-api-production-3f5f.up.railway.app',
    );
  });

  test('local env can still override the server address for development', () {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://10.0.2.2:8080');
    expect(EnvConfig.apiBaseUrl, 'http://10.0.2.2:8080');
  });
}
