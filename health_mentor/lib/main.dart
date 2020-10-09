import 'package:flutter/material.dart';
import 'package:health/health.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future readHealthData() async {
    List<HealthDataPoint> _healthDataList = [];
    DateTime startDate = DateTime.utc(2001, 01, 01);
    DateTime endDate = DateTime.now();

    HealthFactory health = HealthFactory();

    /// Define the types to get.
    List<HealthDataType> types = [
      HealthDataType.DIETARY_FAT_TOTAL,
    ];

    if (await health.requestAuthorization(types, types)) {
      /// Fetch new data
      List<HealthDataPoint> healthData =
          await health.getHealthDataFromTypes(startDate, endDate, types);

      /// Save all the new data points
      _healthDataList.addAll(healthData);

      /// Filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);
    }
  }

  Future writeHealthData() async {
    HealthFactory health = HealthFactory();
    await health.writeHealthData(null, null, null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            TextButton(
              child: Text('Read'),
              onPressed: () {
                readHealthData();
              },
            ),
            TextButton(
              child: Text('Write'),
              onPressed: () {
                writeHealthData();
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
