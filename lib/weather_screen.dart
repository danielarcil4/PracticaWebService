import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String apiKey = 'ab4c3d62abfd3897984bfd6b9be39544'; // Reemplaza con tu clave de API
  List weatherData = [];

  @override
  void initState() {
    super.initState();
    fetchWeatherData();
  }

  Future<void> fetchWeatherData() async {
    final response = await http.get(Uri.parse('http://api.weatherstack.com/current?access_key=$apiKey&query=New York'));
    if (response.statusCode == 200) {
      setState(() {
        weatherData = [json.decode(response.body)];
      });
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  void _addToFavorites(Map item) async {
    final favoritesBox = Hive.box('favorites');
    await favoritesBox.add(item);
  }

  void _showDetails(Map item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['location']['name']),
        content: Text('Temperature: ${item['current']['temperature']}°C\nWeather: ${item['current']['weather_descriptions'][0]}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather App'),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoritesScreen()),
            ),
          ),
        ],
      ),
      body: weatherData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: weatherData.length,
        itemBuilder: (context, index) {
          final item = weatherData[index];
          return ListTile(
            title: Text(item['location']['name']),
            subtitle: Text('Temperature: ${item['current']['temperature']}°C'),
            onTap: () => _showDetails(item),
            trailing: IconButton(
              icon: Icon(Icons.favorite_border),
              onPressed: () => _addToFavorites(item),
            ),
          );
        },
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final favoritesBox = Hive.box('favorites');
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites'),
      ),
      body: ValueListenableBuilder(
        valueListenable: favoritesBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return Center(child: Text('No favorites added.'));
          } else {
            return ListView.builder(
              itemCount: box.length,
              itemBuilder: (context, index) {
                final item = box.getAt(index);
                return ListTile(
                  title: Text(item['location']['name']),
                  subtitle: Text('Temperature: ${item['current']['temperature']}°C'),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(item['location']['name']),
                      content: Text('Temperature: ${item['current']['temperature']}°C\nWeather: ${item['current']['weather_descriptions'][0]}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => box.deleteAt(index),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}