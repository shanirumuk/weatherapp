import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class Forecastpage extends StatefulWidget {
  final String cityName;

  const Forecastpage({Key? key, required this.cityName}) : super(key: key);

  @override
  _ForecastpageState createState() => _ForecastpageState();
}

class _ForecastpageState extends State<Forecastpage> {
  List<DailyForecast> _dailyForecast = [];
  LatLng? _cityLocation;

  @override
  void initState() {
    super.initState();
    _fetchForecastData();
    _getCityLocation();
  }

  Future<void> _getCityLocation() async {
    try {
      List<Location> locations = await locationFromAddress(widget.cityName);
      if (locations.isNotEmpty) {
        setState(() {
          _cityLocation = LatLng(locations.first.latitude, locations.first.longitude);
        });
      } else {
        print('No location found for ${widget.cityName}');
      }
    } catch (e) {
      print('Error getting city location: $e');
    }
  }

  Future<void> _fetchForecastData() async {
    final apiKey = '2d5177a3b6eb5459f01121f61e1cb7d2';
    final url = 'https://api.openweathermap.org/data/2.5/forecast?q=${widget.cityName}&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> forecastList = data['list'];

        final dailyForecast = <DailyForecast>[];
        Map<String, List<double>> dailyTemps = {};

        for (var forecast in forecastList) {
          final date = DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);
          final dateString = DateFormat('yyyy-MM-dd').format(date);
          final temperature = forecast['main']['temp'].toDouble();

          if (!dailyTemps.containsKey(dateString)) {
            dailyTemps[dateString] = [];
          }
          dailyTemps[dateString]!.add(temperature);
        }

        dailyTemps.forEach((dateString, temps) {
          final date = DateTime.parse(dateString);
          final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
          final minTemp = temps.reduce((a, b) => a < b ? a : b);
          final maxTemp = temps.reduce((a, b) => a > b ? a : b);

          dailyForecast.add(DailyForecast(
            date: date,
            temperature: avgTemp,
            minTemperature: minTemp,
            maxTemperature: maxTemp,
          ));
        });

        setState(() {
          _dailyForecast = dailyForecast;
        });
      } else {
        print('Failed to fetch forecast data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching forecast data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1D23),
      appBar: AppBar(
        title: Text('${widget.cityName} - 5 Day Forecast'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    height: 300,
                    child: _dailyForecast.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ListView.builder(
                      itemCount: _dailyForecast.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final forecast = _dailyForecast[index];
                        return ForecastCard(forecast: forecast);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_cityLocation != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Container(
                        height: 300,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: _cityLocation!,
                              initialZoom: 11,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 40.0,
                                    height: 40.0,
                                    point: _cityLocation!,
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    const Center(child: Text('Map loading...', style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ForecastCard extends StatelessWidget {
  final DailyForecast forecast;

  const ForecastCard({Key? key, required this.forecast}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF29222F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('EEE').format(forecast.date),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Icon(
            _getWeatherIcon(forecast.temperature),
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            '${forecast.temperature.round()}°C',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'H:${forecast.maxTemperature.round()}° L:${forecast.minTemperature.round()}°',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(double temperature) {
    if (temperature > 25) {
      return Icons.wb_sunny;
    } else if (temperature > 20) {
      return Icons.cloud_queue;
    } else {
      return Icons.cloud;
    }
  }
}

class DailyForecast {
  final DateTime date;
  final double temperature;
  final double minTemperature;
  final double maxTemperature;

  DailyForecast({
    required this.date,
    required this.temperature,
    required this.minTemperature,
    required this.maxTemperature,
  });
}