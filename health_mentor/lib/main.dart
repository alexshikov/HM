import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';

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
  List<HealthDataPoint> nutrition = List<HealthDataPoint>();
  TextEditingController proteinTextController = TextEditingController();

  Future<List<HealthDataPoint>> readHealthData() async {
    List<HealthDataPoint> _healthDataList = [];
    DateTime startDate = DateTime.utc(2001, 01, 01);
    DateTime endDate = DateTime.now();

    HealthFactory health = HealthFactory();

    /// Define the types to get.
    List<HealthDataType> types = [
      HealthDataType.DIETARY_FAT_TOTAL,
      HealthDataType.DIETARY_PROTEIN,
      HealthDataType.DIETARY_CARBOHYDRATES,
    ];

    if (await health.requestAuthorization(types, types)) {
      /// Fetch new data
      List<HealthDataPoint> healthData =
          await health.getHealthDataFromTypes(startDate, endDate, types);

      /// Save all the new data points
      _healthDataList.addAll(healthData);

      /// Filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);
      return _healthDataList;
    }
    return null;
  }

  Future<bool> writeHealthData() async {
    DateTime date = DateTime.now();
    HealthFactory health = HealthFactory();
    var a = double.tryParse(proteinTextController.text);
    if (a == null) {
      return false;
    }
    return await health.writeHealthData(
      date,
      date,
      HealthDataType.DIETARY_FAT_TOTAL,
      a,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: Text(
                  'From: ${DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(Duration(days: 365)))}',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: Text(
                  'To: ${DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(Duration(days: 365)))}',
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: nutrition
                  .map(
                    (e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      height: 60,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.typeString),
                          Text('${e.value.toString()}')
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextButton(
            child: Text('Read'),
            onPressed: () async {
              nutrition = await readHealthData();
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: InputDecoration(hintText: 'Amount of protein'),
              controller: proteinTextController,
            ),
          ),
          TextButton(
            child: Text('Write'),
            onPressed: () async {
              if (await writeHealthData()) {
                nutrition = await readHealthData();
                setState(() {});
              }
              proteinTextController.clear();
            },
          ),
        ],
      ),
    );
  }
}
