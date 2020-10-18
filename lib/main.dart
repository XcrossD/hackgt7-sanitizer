import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:geocoder/geocoder.dart';

void main() => runApp(MyApp());

const API_KEY = 'API_KEY';

GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: API_KEY);

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

  @override
  Widget build(BuildContext context) {
    Firebase.initializeApp();
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
          : Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('restaurant')
                      .snapshots(),
                  builder: (BuildContext context,
                      AsyncSnapshot<QuerySnapshot> snapshot) {
                    print('firestore run');
                    if (snapshot.hasError) {
                      print('something went wrong');
                      return Text('Something went wrong');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print('firestone is loading');
                      return Text("Loading");
                    }
                    print(snapshot.data.docs);
                    snapshot.data.docs.forEach((queryDocumentSnapshot) {
                      final doc = queryDocumentSnapshot.data();
                      final marker = Marker(
                          markerId: MarkerId(doc['name']),
                          position: LatLng(doc['lat'], doc['lng']),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              doc['has_sanitizer']
                                  ? BitmapDescriptor.hueGreen
                                  : BitmapDescriptor.hueRed),
                          infoWindow: InfoWindow(
                              title: doc['has_sanitizer']
                                  ? doc['name'] + ' (Hand sanitizer available)'
                                  : doc['name'] + ' (No hand sanitizer)',
                              snippet: doc['address']));
                      // setState(() {
                      _markers[queryDocumentSnapshot.id] = marker;
                      // });
                    });
                    return GoogleMap(
                      zoomGesturesEnabled: true,
                      initialCameraPosition: CameraPosition(
                        // target: const LatLng(0, 0),
                        // zoom: 2,
                        target: _center,
                        zoom: 15.0,
                      ),
                      myLocationEnabled: true,
                      markers: _markers.values.toSet(),
                    );
                  },
                ),
              ],
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
  Prediction place;
  String restaurantName;
  double latitude;
  double longitutude;
  int hasHandSanitizer = 0;

  final nameController = TextEditingController();

  void _showToast(BuildContext context) {
    final scaffold = Scaffold.of(context);
    scaffold.showSnackBar(SnackBar(
      content: const Text('Restaurant added'),
    ));
  }

  Text _showRestaurantInfo() {
    String text = (place == null ? '' : place.description);
    return Text(text);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    nameController.dispose();
    super.dispose();
  }

  Future<Null> displayPrediction(Prediction p) async {
    if (p != null) {
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId(p.placeId);

      var placeId = p.placeId;
      double lat = detail.result.geometry.location.lat;
      double lng = detail.result.geometry.location.lng;

      var address = await Geocoder.local.findAddressesFromQuery(p.description);

      setState(() {
        place = p;
        restaurantName = p.terms[0].value;
        latitude = lat;
        longitutude = lng;
      });

      print(lat);
      print(lng);
      print(p.terms);
    }
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference restaurant =
        FirebaseFirestore.instance.collection('restaurant');

    Future<void> addRestaurant() {
      // Call the user's CollectionReference to add a new user
      return restaurant
          .doc(restaurantName.toLowerCase().replaceAll(RegExp(r"\s+"), ""))
          .set({
        'name': restaurantName,
        'address': place.description,
        'lat': latitude,
        'lng': longitutude,
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
            child: ListView(
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    Prediction p = await PlacesAutocomplete.show(
                      context: context,
                      apiKey: API_KEY,
                    );

                    await displayPrediction(p);
                  },
                  child: Text(
                    'Enter name',
                    style: Theme.of(context).textTheme.headline4,
                  ),
                ),
                Text(''),
                _showRestaurantInfo(),
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
                    addRestaurant();
                    _showToast(context);
                    setState(() {
                      place = null;
                    });
                    // Navigator.pop(context);
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
