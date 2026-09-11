import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:folio/services/weather/weather_client.dart';

void main() {
  test('fetchCurrent geocodes and returns temperature', () async {
    var calls = 0;
    final client = WeatherClient(
      httpClient: MockClient((request) async {
        calls++;
        if (request.url.host.contains('geocoding')) {
          return http.Response(
            '{"results":[{"name":"Madrid","admin1":"Madrid","country":"Spain","latitude":40.4,"longitude":-3.7}]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"current":{"temperature_2m":21.5,"weather_code":0,"wind_speed_10m":3.2}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final snap = await client.fetchCurrent(city: 'Madrid', celsius: true);
    expect(snap.temperature, 21.5);
    expect(snap.temperatureLabel, '22°C');
    expect(snap.conditionLabel, 'Despejado');
    expect(snap.cityLabel, contains('Madrid'));
    expect(calls, 2);

    // Cache hit — no more HTTP.
    await client.fetchCurrent(city: 'Madrid', celsius: true);
    expect(calls, 2);
  });

  test('unknown city throws WeatherException', () async {
    final client = WeatherClient(
      httpClient: MockClient((request) async {
        return http.Response(
          '{"results":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => client.fetchCurrent(city: 'Zzznolugar', celsius: true),
      throwsA(isA<WeatherException>()),
    );
  });
}
