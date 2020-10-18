import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HackGT7 Sanitizer',
      home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() {
    return _MapPageState();
  }
}

class _MapPageState extends State<MapPage> {
  LatLng _center;
  // LatLng _center = LatLng(32.602798, -85.488960);
  final Map<String, Marker> _markers = {};

  final Geolocator geolocator = Geolocator()..forceAndroidLocationManager;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _getCurrentLocation() {
    geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((Position position) {
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });
    }).catchError((e) {
      print(e);
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    setState(() {
      _markers.clear();
      Firestore.instance.collection('restaurant').getDocuments().then((docs) {
        docs.documents.forEach((doc) {
          print(doc.documentID);
          final marker = Marker(
              markerId: MarkerId(doc['name']),
              position: LatLng(doc['lat'], doc['lng']),
              icon: BitmapDescriptor.defaultMarkerWithHue(doc['has_sanitizer']
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: doc['name'],
                snippet: doc['address'],
              ));
          setState(() {
            _markers[doc.documentID] = marker;
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HackGT7 Sanitizer'), actions: <Widget>[
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserPage()),
            );
          },
        ),
      ]),
      // body: _buildBody(context),
      body: _center == null
          ? Container(
              child: Center(
                child: Text(
                  'loading map..',
                  style: TextStyle(
                      fontFamily: 'Avenir-Medium', color: Colors.grey[400]),
                ),
              ),
            )
          : GoogleMap(
              onMapCreated: _onMapCreated,
              zoomGesturesEnabled: true,
              initialCameraPosition: CameraPosition(
                // target: const LatLng(0, 0),
                // zoom: 2,
                target: _center,
                zoom: 15.0,
              ),
              myLocationEnabled: true,
              markers: _markers.values.toSet(),
            ),
    );
  }
}

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() {
    return _UserPageState();
  }
}

class _UserPageState extends State<UserPage> {
  String restaurantName;
  String address;
  String latitude;
  String longitude;
  int hasHandSanitizer = 0;

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();

  void _showToast(BuildContext context) {
    final scaffold = Scaffold.of(context);
    scaffold.showSnackBar(SnackBar(
      content: const Text('Restaurant added'),
    ));
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference restaurant =
        Firestore.instance.collection('restaurant');

    Future<void> addRestaurant() {
      // Call the user's CollectionReference to add a new user
      return restaurant
          .document(restaurantName.toLowerCase().replaceAll(RegExp(r"\s+"), ""))
          .setData({
        'name': restaurantName,
        'address': address,
        'lat': double.parse(latitude),
        'lng': double.parse(longitude),
        'has_sanitizer': (hasHandSanitizer == 1 ? true : false),
      }).then((value) {
        print('Restaurant Added');
      }).catchError((error) => print('Failed to add restaurant: $error'));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Submit a restaurant')),
      // body: _buildBody(context),
      body: Builder(
        builder: (context) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Restaurant',
                  ),
                  controller: nameController,
                ),
                Text(''),
                TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Address',
                  ),
                  controller: addressController,
                ),
                Text(''),
                TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Latitude',
                  ),
                  controller: latController,
                ),
                Text(''),
                TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Longitude',
                  ),
                  controller: lngController,
                ),
                Text(''),
                Row(
                  children: [
                    Text('Offers Hand Sanitizer?'),
                    Padding(
                      padding: EdgeInsets.all(10.0),
                    ),
                    Radio<int>(
                      value: 1,
                      groupValue: hasHandSanitizer,
                      onChanged: (int val) {
                        setState(() {
                          hasHandSanitizer = val;
                        });
                      },
                    ),
                    Text('Yes'),
                    Padding(
                      padding: EdgeInsets.all(10.0),
                    ),
                    Radio<int>(
                      value: 0,
                      groupValue: hasHandSanitizer,
                      onChanged: (int val) {
                        setState(() {
                          hasHandSanitizer = val;
                        });
                      },
                    ),
                    Text('No'),
                  ],
                ),
                Text(''),
                ElevatedButton(
                  onPressed: () {
                    restaurantName = nameController.text;
                    address = addressController.text;
                    latitude = latController.text;
                    longitude = lngController.text;
                    if (restaurantName != "" &&
                        address != "" &&
                        double.tryParse(latitude) != null &&
                        double.tryParse(longitude) != null) {
                      addRestaurant();
                      _showToast(context);
                      // Navigator.pop(context);
                    }
                  },
                  child: Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
