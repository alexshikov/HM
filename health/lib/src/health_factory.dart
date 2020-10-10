part of health;

/// Main class for the Plugin
class HealthFactory {
  static const MethodChannel _channel = const MethodChannel('flutter_health');
  String _deviceId;
  DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static PlatformType _platformType =
      Platform.isAndroid ? PlatformType.ANDROID : PlatformType.IOS;

  /// Check if a given data type is available on the platform
  bool _isDataTypeAvailable(HealthDataType dataType) =>
      _platformType == PlatformType.ANDROID
          ? _dataTypeKeysAndroid.contains(dataType)
          : _dataTypeKeysIOS.contains(dataType);

  /// Request access to GoogleFit/Apple HealthKit
  Future<bool> requestAuthorization(
    List<HealthDataType> readTypes,
    List<HealthDataType> writeTypes,
  ) async {
    /// If BMI is requested, then also ask for weight and height
    if (readTypes.contains(HealthDataType.BODY_MASS_INDEX)) {
      readTypes.add(HealthDataType.WEIGHT);
      readTypes.add(HealthDataType.HEIGHT);
      readTypes = readTypes.toSet().toList();
    }

    List<String> readKeys = readTypes.map((e) => _enumToString(e)).toList();
    List<String> writeKeys = writeTypes?.map((e) => _enumToString(e))?.toList();
    final bool isAuthorized = await _channel.invokeMethod(
      'requestAuthorization',
      {
        'types': readKeys,
        'writeTypes': writeKeys,
      },
    );
    return isAuthorized;
  }

  /// Calculate the BMI using the last observed height and weight values.
  Future<List<HealthDataPoint>> _computeAndroidBMI(
      DateTime startDate, DateTime endDate) async {
    List<HealthDataPoint> heights =
        await _prepareQuery(startDate, endDate, HealthDataType.HEIGHT);
    List<HealthDataPoint> weights =
        await _prepareQuery(startDate, endDate, HealthDataType.WEIGHT);

    double h = heights.last.value.toDouble();

    HealthDataType dataType = HealthDataType.BODY_MASS_INDEX;
    HealthDataUnit unit = _dataTypeToUnit[dataType];

    List<HealthDataPoint> bmiHealthPoints = [];
    for (int i = 0; i < weights.length; i++) {
      double bmiValue = weights[i].value.toDouble() / (h * h);
      print('BMI: $bmiValue');
      HealthDataPoint x = HealthDataPoint._(
          bmiValue,
          HealthDataType.BODY_MASS_INDEX,
          unit,
          weights[i].dateFrom,
          weights[i].dateTo,
          _platformType,
          _deviceId);

      bmiHealthPoints.add(x);
    }
    return bmiHealthPoints;
  }

  /// Get an array of [HealthDataPoint] from an array of [HealthDataType]
  Future<List<HealthDataPoint>> getHealthDataFromTypes(
      DateTime startDate, DateTime endDate, List<HealthDataType> types) async {
    List<HealthDataPoint> dataPoints = [];
    bool granted = await requestAuthorization(types, types);
    // for (HealthDataType type in types) {
    //   bool p = await requestAuthorization([type], [type]);
    //   print('$type, $p');
    // }

    if (!granted) {
      String api =
          _platformType == PlatformType.ANDROID ? "Google Fit" : "Apple Health";
      throw _HealthException(types, "Permission was not granted for $api");
    }
    for (HealthDataType type in types) {
      List<HealthDataPoint> result =
          await _prepareQuery(startDate, endDate, type);
      dataPoints.addAll(result);
    }
    return removeDuplicates(dataPoints);
  }

  Future<bool> writeHealthData(
    DateTime startDate,
    DateTime endDate,
    HealthDataType type,
    double value,
  ) async {
    var granted = await requestAuthorization([type], [type]);

    if (granted) {
      Map<String, dynamic> args = {
        'dataTypeKey': _enumToString(type),
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'value': value,
      };

      try {
        bool writeDataResult = await _channel.invokeMethod('writeData', args);
        return writeDataResult;
      } catch (error) {
        print(error);
        return false;
      }
    }
    return false;
  }

  /// Prepares a query, i.e. checks if the types are available, etc.
  Future<List<HealthDataPoint>> _prepareQuery(
      DateTime startDate, DateTime endDate, HealthDataType dataType) async {
    /// Ask for device ID only once
    if (_deviceId == null) {
      _deviceId = _platformType == PlatformType.ANDROID
          ? (await _deviceInfo.androidInfo).androidId
          : (await _deviceInfo.iosInfo).identifierForVendor;
    }

    /// If not implemented on platform, throw an exception
    if (!_isDataTypeAvailable(dataType)) {
      throw _HealthException(
          dataType, "Not available on platform $_platformType");
    }

    /// If BodyMassIndex is requested on Android, calculate this manually in Dart
    if (dataType == HealthDataType.BODY_MASS_INDEX &&
        _platformType == PlatformType.ANDROID) {
      return _computeAndroidBMI(startDate, endDate);
    }
    if (dataType == HealthDataType.NUTRIENTS &&
        _platformType == PlatformType.ANDROID) {
      return _nutrientsQuery(startDate, endDate);
    }
    return await _dataQuery(startDate, endDate, dataType);
  }

  /// The main function for fetching health data
  Future<List<HealthDataPoint>> _dataQuery(
      DateTime startDate, DateTime endDate, HealthDataType dataType) async {
    // Set parameters for method channel request
    Map<String, dynamic> args = {
      'dataTypeKey': _enumToString(dataType),
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch
    };

    List<HealthDataPoint> healthData = new List();
    HealthDataUnit unit = _dataTypeToUnit[dataType];

    try {
      List fetchedDataPoints = await _channel.invokeMethod('getData', args);
      healthData = fetchedDataPoints?.map((e) {
            num value = e["value"];
            DateTime from = DateTime.fromMillisecondsSinceEpoch(e["date_from"]);
            DateTime to = DateTime.fromMillisecondsSinceEpoch(e["date_to"]);
            return HealthDataPoint._(
                value, dataType, unit, from, to, _platformType, _deviceId);
          })?.toList() ??
          [];
    } catch (error) {
      print("Health Plugin Error:\n");
      print("\t$error");
    }
    return healthData;
  }

  /// Fetch Nutrients for Android
  Future<List<HealthDataPoint>> _nutrientsQuery(DateTime startDate, DateTime endDate) async {
    // Set parameters for method channel request
    Map<String, dynamic> args = {
      'dataTypeKey': _enumToString(HealthDataType.NUTRIENTS),
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch
    };

    List<HealthDataPoint> healthData = new List();
    HealthDataUnit unit = _dataTypeToUnit[HealthDataType.NUTRIENTS];

    try {
      List fetchedDataPoints = await _channel.invokeMethod('getData', args);

      if (fetchedDataPoints == null) {
        return [];
      }

      var list = List<HealthDataPoint>();
      for (var dataPoint in fetchedDataPoints) {

        var nutrition = jsonDecode(dataPoint["value"]);
        num fat = nutrition["fat.total"];
        num protein = nutrition["protein"];
        num carbs = nutrition["carbs.total"];

        DateTime from = DateTime.fromMillisecondsSinceEpoch(dataPoint["date_from"]);
        DateTime to = DateTime.fromMillisecondsSinceEpoch(dataPoint["date_to"]);

        list.add(HealthDataPoint._(fat, HealthDataType.DIETARY_FAT_TOTAL, unit, from, to, _platformType, _deviceId));
        list.add(HealthDataPoint._(protein, HealthDataType.DIETARY_PROTEIN, unit, from, to, _platformType, _deviceId));
        list.add(HealthDataPoint._(carbs, HealthDataType.DIETARY_CARBOHYDRATES, unit, from, to, _platformType, _deviceId));
      }

      return list;
    } catch (error) {
      print("Health Plugin Error:\n");
      print("\t$error");
    }
    return healthData;
  }


  /// Given an array of [HealthDataPoint]s, this method will return the array
  /// without any duplicates.
  static List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) {
    List<HealthDataPoint> unique = [];

    for (HealthDataPoint p in points) {
      bool seenBefore = false;
      for (HealthDataPoint s in unique) {
        if (s == p) {
          seenBefore = true;
        }
      }
      if (!seenBefore) {
        unique.add(p);
      }
    }
    return unique;
  }
}
