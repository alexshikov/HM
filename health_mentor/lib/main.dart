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
  var fatTextController = TextEditingController();
  var proteinTextController = TextEditingController();
  var carbohydratsTextController = TextEditingController();

  Future<List<HealthDataPoint>> readHealthData() async {
    List<HealthDataPoint> _healthDataList = [];
    DateTime startDate = DateTime.now().subtract(Duration(days: 7));
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
    var fat = double.tryParse(fatTextController.text);
    var protein = double.tryParse(proteinTextController.text);
    var carbohydrates = double.tryParse(carbohydratsTextController.text);

    if (fat != null) {
      var a = await health.writeHealthData(
        date,
        date,
        HealthDataType.DIETARY_FAT_TOTAL,
        fat,
      );
    }

    if (protein != null) {
      var b = await health.writeHealthData(
        date,
        date,
        HealthDataType.DIETARY_PROTEIN,
        protein,
      );
      var c = b;
    }

    if (carbohydrates != null) {
      var c = await health.writeHealthData(
        date,
        date,
        HealthDataType.DIETARY_CARBOHYDRATES,
        carbohydrates,
      );
    }

    return true;
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
                  'From: ${DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(Duration(days: 7)))}',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: Text(
                  'To: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
              child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Fat'),
                    Expanded(
                      child: ListView(
                        children: nutrition
                            .where((element) =>
                                element.type ==
                                HealthDataType.DIETARY_FAT_TOTAL)
                            .map(
                              (e) => Container(
                                alignment: Alignment.center,
                                height: 30,
                                child: Text(
                                    '${DateFormat('dd/MM').format(e.dateTo)}: ${e.value.toInt()}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                        'Total: ${nutrition.where((element) => element.type == HealthDataType.DIETARY_FAT_TOTAL).map((e) => e.value).fold(0, (value, element) => value + element.toInt())}'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Protein'),
                    Expanded(
                      child: ListView(
                        children: nutrition
                            .where((element) =>
                                element.type == HealthDataType.DIETARY_PROTEIN)
                            .map(
                              (e) => Container(
                                alignment: Alignment.center,
                                height: 30,
                                child: Text(
                                    '${DateFormat('dd/MM').format(e.dateTo)}: ${e.value.toInt()}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Total: ${nutrition.isEmpty ? 0 : nutrition.where((element) => element.type == HealthDataType.DIETARY_PROTEIN).map((e) => e.value).fold<int>(0, (value, element) => value + element.toInt())}',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Carbo'),
                    Expanded(
                      child: ListView(
                        children: nutrition
                            .where((element) =>
                                element.type ==
                                HealthDataType.DIETARY_CARBOHYDRATES)
                            .map(
                              (e) => Container(
                                alignment: Alignment.center,
                                height: 30,
                                child: Text(
                                    '${DateFormat('dd/MM').format(e.dateTo)}: ${e.value.toInt()}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Total: ${nutrition.isEmpty ? 0 : nutrition.where((element) => element.type == HealthDataType.DIETARY_CARBOHYDRATES).map((e) => e.value).fold(0, (value, element) => value + element.toInt())}',
                    ),
                  ],
                ),
              ),
            ],
          )),
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
              decoration: InputDecoration(hintText: 'Amount of fat'),
              controller: fatTextController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: InputDecoration(hintText: 'Amount of protein'),
              controller: proteinTextController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: InputDecoration(hintText: 'Amount of carbohydrates'),
              controller: carbohydratsTextController,
            ),
          ),
          TextButton(
            child: Text('Write'),
            onPressed: () async {
              if (await writeHealthData()) {
                nutrition = await readHealthData();
                setState(() {});
              }
              fatTextController.clear();
              proteinTextController.clear();
              carbohydratsTextController.clear();
            },
          ),
        ],
      ),
    );
  }
}
