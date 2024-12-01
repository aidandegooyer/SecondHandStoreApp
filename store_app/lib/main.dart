import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Django API Integration',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ApiDemoScreen(),
    );
  }
}

class ApiDemoScreen extends StatelessWidget {
  final String baseUrl = 'http://10.0.2.2:8000/upload'; // Update based on your Django server

  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final List<int> dummyImageBytes = [
      0x00, 0x00, 0x00, 0x00 // RGBA: transparent pixel
    ];
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploadImage/'));
    request.files.add(await http.MultipartFile.fromBytes('image', dummyImageBytes, filename: 'dummy_image.png'));

    var response = await request.send();
    if (response.statusCode == 200) {
      return json.decode(await response.stream.bytesToString());
    } else {
      throw Exception('Failed to upload image');
    }
  }

  Future<Map<String, dynamic>> createListing(String name, String description, double price, String filePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/createListing/'));
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price.toString();
    request.files.add(await http.MultipartFile.fromPath('image', filePath));

    var response = await request.send();
    if (response.statusCode == 201) {
      return json.decode(await response.stream.bytesToString());
    } else {
      throw Exception('Failed to create listing');
    }
  }

  Future<List<dynamic>> getNext(int itemsToSend, int idToStart, {String searchTerm = ""}) async {
    final uri = Uri.parse('$baseUrl/getNext/')
        .replace(queryParameters: {
      'itemsToSend': itemsToSend.toString(),
      'idToStart': idToStart.toString(),
      'searchTerm': searchTerm,
    });
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body)['items'];
    } else {
      throw Exception('Failed to fetch items');
    }
  }

  Future<void> editListing(int itemNumber, String name, String description, double price) async {
    final response = await http.put(
      Uri.parse('$baseUrl/editListing/$itemNumber/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'description': description,
        'price': price,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to edit listing');
    }
  }

  Future<void> deleteListing(int itemNumber) async {
    var response = await http.delete(Uri.parse('$baseUrl/deleteListing/$itemNumber/'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete listing');
    }
  }

  Future<String> getCsrfToken() async {
    var response = await http.get(Uri.parse('$baseUrl/get-csrf-token/'));
    if (response.statusCode == 200) {
      return json.decode(response.body)['csrfToken'];
    } else {
      throw Exception('Failed to fetch CSRF token');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Listing')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Example: Create listing with hardcoded values
              final name = 'Sample Product';
              final description = 'This is a sample product description';
              final price = 19.99;
              final filePath = '/path/to/your/image.jpg'; // Replace with a valid image file path

              final response = await createListing(name, description, price, filePath);
              print('Create Listing Response: $response');
            } catch (e) {
              print('Error: $e');
            }
          },
          child: Text('Create Listing'),
        ),
      ),
    );
  }
}
