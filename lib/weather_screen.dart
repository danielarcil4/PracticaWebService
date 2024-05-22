import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('favorites');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String apiKey = 'ab4c3d62abfd3897984bfd6b9be39544'; // Reemplaza con tu clave de API
  List<String> cities = ['New York', 'Los Angeles', 'Chicago']; // Lista de ciudades iniciales
  List<Map<String, dynamic>> weatherData = [];
  final Box favoritesBox = Hive.box('favorites');
  final TextEditingController cityController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchWeatherData();
  }

  Future<void> fetchWeatherData() async {
    setState(() {
      isLoading = true;
    });

    List<Map<String, dynamic>> tempWeatherData = [];
    for (String city in cities) {
      final response = await http.get(Uri.parse('http://api.weatherstack.com/current?access_key=$apiKey&query=$city'));
      if (response.statusCode == 200) {
        tempWeatherData.add(json.decode(response.body));
      } else {
        _showError('Failed to load weather data for $city');
      }
    }
    setState(() {
      weatherData = tempWeatherData;
      isLoading = false;
    });
  }

  void _addToFavorites(Map item) async {
    final locationName = item['location']['name'];
    final existingItem = favoritesBox.values.firstWhere(
          (favorite) => favorite['location']['name'] == locationName,
      orElse: () => null,
    );

    if (existingItem == null) {
      await favoritesBox.add(item);
    } else {
      int key = favoritesBox.keyAt(favoritesBox.values.toList().indexOf(existingItem));
      await favoritesBox.delete(key);
    }

    setState(() {}); // Refresh the state to update the icon
  }

  bool _isFavorite(String cityName) {
    return favoritesBox.values.any((favorite) => favorite['location']['name'] == cityName);
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addCity() {
    final newCity = cityController.text.trim();
    if (newCity.isNotEmpty && !cities.contains(newCity)) {
      setState(() {
        cities.add(newCity);
        cityController.clear();
      });
      fetchWeatherData();
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      hintText: 'Enter city name',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addCity,
                ),
              ],
            ),
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
            child: ListView.builder(
              itemCount: weatherData.length,
              itemBuilder: (context, index) {
                final item = weatherData[index];
                final cityName = item['location']['name'];
                final isFavorite = _isFavorite(cityName);
                return ListTile(
                  title: Text(cityName),
                  subtitle: Text('Temperature: ${item['current']['temperature']}°C'),
                  onTap: () => _showDetails(item),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () => _addToFavorites(item),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: fetchWeatherData,
              child: const Text('Update Weather Data'),
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesBox = Hive.box('favorites');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: ValueListenableBuilder(
        valueListenable: favoritesBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No favorites added.'));
          } else {
            return ListView.builder(
              itemCount: box.length,
              itemBuilder: (context, index) {
                final item = box.getAt(index) as Map;
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
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      box.deleteAt(index);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item['location']['name']} removed from favorites')),
                      );
                    },
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
