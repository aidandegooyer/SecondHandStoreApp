import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

// App-wide variables
const String baseUrl = 'http://10.0.2.2:8000/upload';
const String baseIP = 'http://10.0.2.2:8000';
int total = 0;

// API Calls
Future<Map<String, dynamic>> uploadImage() async {
  // Example: Create a dummy image as a byte list (in real-world, you would use a file path)
  final List<int> dummyImageBytes = [
    0x00, 0x00, 0x00, 0x00 // RGBA: transparent pixel
  ];

  // Send image data as a multipart request
  var request =
      http.MultipartRequest('POST', Uri.parse('$baseUrl/uploadImage/'));
  request.files.add(http.MultipartFile.fromBytes('image', dummyImageBytes,
      filename: 'dummy_image.png'));

  var response = await request.send();
  if (response.statusCode == 200) {
    return json.decode(await response.stream.bytesToString());
  } else {
    throw Exception('Failed to upload image');
  }
}

Future<Map<String, dynamic>> createListing(
    String name, String description, double price) async {
  try {
    // Load the image as bytes from assets
    final ByteData byteData =
        await rootBundle.load('assets/defaultProfilePic.jpg');
    final List<int> imageBytes = byteData.buffer.asUint8List();

    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/createListing/'));
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price.toString();

    // Add the image bytes to the request
    request.files.add(http.MultipartFile.fromBytes('image', imageBytes,
        filename: 'sample_image.jpg'));

    // Send the request
    var response = await request.send();

    // Check the server response
    if (response.statusCode == 201) {
      return json.decode(await response.stream.bytesToString());
    } else {
      throw Exception('Failed to create listing');
    }
  } catch (e) {
    print('Error: $e');
    rethrow; // Re-throw the error to handle it properly in UI or logs
  }
}

Future<List<dynamic>> getNext(
    int itemsToSend, int idToStart, String searchTerm) async {
  // Construct the URL with parameters in the path
  final uri = Uri.parse('$baseUrl/getNext/$itemsToSend/$idToStart/$searchTerm');

  // Make the GET request
  final response = await http.get(uri);

  if (response.statusCode == 200) {
    // Decode the main response
    final decodedBody = json.decode(response.body);

    // Decode the JSON-encoded "items" string into a list
    if (decodedBody is Map<String, dynamic> && decodedBody['items'] is String) {
      final items = json.decode(decodedBody['items']);
      total = decodedBody['total_count'];
      if (items is List) {
        return items;
      } else {
        throw Exception('Invalid format: "items" is not a list');
      }
    } else {
      throw Exception(
          'Invalid response format: "items" key missing or not a string');
    }
  } else {
    throw Exception('Failed to fetch items: ${response.statusCode}');
  }
}

Future<void> editListing(
    int itemNumber, String name, String description, double price) async {
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
  var response =
      await http.delete(Uri.parse('$baseUrl/deleteListing/$itemNumber/'));
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Django API Integration',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Main theme color
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, // Button color
            foregroundColor: Colors.white, // Text color
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromARGB(
              115, 200, 230, 255), // Background color of text box
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0), // Rounded corners
            borderSide: BorderSide(
              color: Colors.blue, // Border color
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.blue.shade700, // Focused border color
              width: 2.0,
            ),
          ),
        ),
      ),
      home: const Marketplace(),
    );
  }
}

class Marketplace extends StatefulWidget {
  const Marketplace({super.key});

  @override
  _MarketplaceState createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace> {
  List<dynamic> items = [];
  bool isLoading = false;
  int currentPage = 0;
  final int itemsPerPage = 10; // Number of items per page
  String searchQuery = ''; // Store the search query here
  TextEditingController searchController = TextEditingController();

  // Fetch items with the search query and page info
  Future<void> fetchItems({required int page, String query = ''}) async {
    setState(() {
      isLoading = true;
    });

    int idToStart = page * itemsPerPage; // Calculate the starting ID
    try {
      // Pass the search query to the API
      final fetchedItems = await getNext(itemsPerPage, idToStart, query);
      setState(() {
        items = fetchedItems;
        currentPage = page; // Update the current page
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch items: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Called when the search button is pressed
  void searchItems() {
    String query = searchController.text;
    setState(() {
      searchQuery = query; // Store the search term
      currentPage = 0; // Reset to the first page
    });
    fetchItems(page: 0, query: searchQuery); // Fetch with the search query
  }

  void showItemDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item['fields']['name']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item['fields']['image'] != "null")
                Image.network(
                  '$baseIP/media/${item['fields']['image']}',
                  fit: BoxFit.cover,
                ),
              SizedBox(height: 10),
              Text(
                'Description: ${item['fields']['description']}',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                'Price: \$${item['fields']['price']}',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void handlePreviousPage() {
    if (currentPage > 0) {
      fetchItems(
          page: currentPage - 1,
          query: searchQuery); // Pass search term on previous page
    }
  }

  void handleNextPage() {
    fetchItems(
        page: currentPage + 1,
        query: searchQuery); // Pass search term on next page
  }

  @override
  void initState() {
    super.initState();
    fetchItems(page: 0, query: searchQuery); // Load the first page initially
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Marketplace'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Marketplace()),
                );
              },
            ),
            ListTile(
              title: const Text('Upload'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Upload()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search TextField and Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search for items',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed:
                      searchItems, // Trigger search when button is pressed
                ),
              ],
            ),
          ),

          // Loading indicator or list of items
          isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      const baseUrl = '$baseIP/media/';
                      final item = items[index];
                      final imagePath = item['fields']['image'];
                      final imageUrl = imagePath != null && imagePath != 'null'
                          ? '$baseUrl$imagePath'
                          : null;
                      return ListTile(
                        onTap: () => showItemDetails(item),
                        leading: imageUrl != null && imageUrl != 'null'
                            ? Image.network(imageUrl,
                                width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 50),
                        title: Text(item['fields']['name']),
                        subtitle: Text(item['fields']['description']),
                        trailing: Text('\$${item['fields']['price']}'),
                      );
                    },
                  ),
                ),

          // Pagination buttons
          Padding(
            padding: const EdgeInsets.only(
                top: 10.0, bottom: 15.0), // Adjust the vertical position
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft:
                            Radius.circular(8.0), // Connect top-left corner
                        bottomLeft:
                            Radius.circular(8.0), // Connect bottom-left corner
                      ),
                    ),
                  ),
                  onPressed: currentPage > 0 && !isLoading
                      ? handlePreviousPage
                      : null, // Disable if on the first page or loading
                  child: const Text('<<'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight:
                            Radius.circular(8.0), // Connect top-right corner
                        bottomRight:
                            Radius.circular(8.0), // Connect bottom-right corner
                      ),
                    ),
                  ),
                  onPressed: !isLoading && (10 * currentPage < total - 10)
                      ? handleNextPage
                      : null, // Disable if loading
                  child: const Text('>>'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Upload extends StatefulWidget {
  const Upload({super.key});

  @override
  _UploadState createState() => _UploadState();
}

class _UploadState extends State<Upload> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  XFile? image; // To store the selected image

  // Image Picker instance
  final ImagePicker _picker = ImagePicker();

  // Pick an image from gallery
  Future<void> _pickImage() async {
    final XFile? pickedImage =
        await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      image = pickedImage;
    });
  }

  Future<void> _uploadProduct() async {
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    final name = _nameController.text;
    final description = _descriptionController.text;
    final price = double.tryParse(_priceController.text);

    if (name.isEmpty || description.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Call the createListing function to upload the data
    try {
      final response = await createListing(name, description, price, image!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload successful: ${response['message']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  // Function to create listing (send product data and image)
  Future<Map<String, dynamic>> createListing(
      String name, String description, double price, XFile imageFile) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/createListing/'));

      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['price'] = price.toString();

      // Add the image file to the request
      request.files.add(await http.MultipartFile.fromPath(
          'image', imageFile.path,
          filename: imageFile.name));

      var response = await request.send();

      if (response.statusCode == 201) {
        return json.decode(await response.stream.bytesToString());
      } else {
        throw Exception('Failed to create listing');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Item'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Marketplace'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Marketplace()),
                );
              },
            ),
            ListTile(
              title: const Text('Upload'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Upload()),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Name:'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Description:'),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Price:'),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // Display the selected image if any
            image == null
                ? const Text('No image selected.')
                : Image.file(File(image!.path)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Select Image'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _uploadProduct,
              child: const Text('Upload Product'),
            ),
          ],
        ),
      ),
    );
  }
}
