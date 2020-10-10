package cachet.plugins.health

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.fitness.result.DataReadResponse
import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field
import com.google.android.gms.tasks.Tasks
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import android.content.Intent
import android.os.Handler
import android.util.Log
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import com.google.android.gms.fitness.data.*
import org.json.JSONObject
import kotlin.collections.HashMap

const val GOOGLE_FIT_PERMISSIONS_REQUEST_CODE = 1111

class HealthPlugin(val activity: Activity, val channel: MethodChannel) : MethodCallHandler, ActivityResultListener, Result {

    private var result: Result? = null
    private var handler: Handler? = null

    private var BODY_FAT_PERCENTAGE = "BODY_FAT_PERCENTAGE"
    private var HEIGHT = "HEIGHT"
    private var WEIGHT = "WEIGHT"
    private var STEPS = "STEPS"
    private var ACTIVE_ENERGY_BURNED = "ACTIVE_ENERGY_BURNED"
    private var HEART_RATE = "HEART_RATE"
    private var BODY_TEMPERATURE = "BODY_TEMPERATURE"
    private var BLOOD_PRESSURE_SYSTOLIC = "BLOOD_PRESSURE_SYSTOLIC"
    private var BLOOD_PRESSURE_DIASTOLIC = "BLOOD_PRESSURE_DIASTOLIC"
    private var BLOOD_OXYGEN = "BLOOD_OXYGEN"
    private var BLOOD_GLUCOSE = "BLOOD_GLUCOSE"
    private var MOVE_MINUTES = "MOVE_MINUTES"
    private var DISTANCE_DELTA = "DISTANCE_DELTA"
    private var NUTRIENTS = "NUTRIENTS"

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_health")
            val plugin = HealthPlugin(registrar.activity(), channel)
            registrar.addActivityResultListener(plugin)
            channel.setMethodCallHandler(plugin)
        }
    }

    override fun success(p0: Any?) {
        handler?.post(
                Runnable { result?.success(p0) })
    }

    override fun notImplemented() {
        handler?.post(
                Runnable { result?.notImplemented() })
    }

    override fun error(
            errorCode: String, errorMessage: String?, errorDetails: Any?) {
        handler?.post(
                Runnable { result?.error(errorCode, errorMessage, errorDetails) })
    }


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_FIT_PERMISSIONS_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                Log.d("FLUTTER_HEALTH", "Access Granted!")
                mResult?.success(true)
            } else if (resultCode == Activity.RESULT_CANCELED) {
                Log.d("FLUTTER_HEALTH", "Access Denied!")
                mResult?.success(false);
            }
        }
        return false
    }

    private var mResult: Result? = null

    private fun keyToHealthDataType(type: String): DataType {
        return when (type) {
            BODY_FAT_PERCENTAGE -> DataType.TYPE_BODY_FAT_PERCENTAGE
            HEIGHT -> DataType.TYPE_HEIGHT
            WEIGHT -> DataType.TYPE_WEIGHT
            STEPS -> DataType.TYPE_STEP_COUNT_DELTA
            ACTIVE_ENERGY_BURNED -> DataType.TYPE_CALORIES_EXPENDED
            HEART_RATE -> DataType.TYPE_HEART_RATE_BPM
            BODY_TEMPERATURE -> HealthDataTypes.TYPE_BODY_TEMPERATURE
            BLOOD_PRESSURE_SYSTOLIC -> HealthDataTypes.TYPE_BLOOD_PRESSURE
            BLOOD_PRESSURE_DIASTOLIC -> HealthDataTypes.TYPE_BLOOD_PRESSURE
            BLOOD_OXYGEN -> HealthDataTypes.TYPE_OXYGEN_SATURATION
            BLOOD_GLUCOSE -> HealthDataTypes.TYPE_BLOOD_GLUCOSE
            MOVE_MINUTES -> DataType.TYPE_MOVE_MINUTES
            DISTANCE_DELTA -> DataType.TYPE_DISTANCE_DELTA
            NUTRIENTS -> DataType.TYPE_NUTRITION
            else -> DataType.TYPE_STEP_COUNT_DELTA
        }
    }

    private fun getUnit(type: String): Field {
        return when (type) {
            BODY_FAT_PERCENTAGE -> Field.FIELD_PERCENTAGE
            HEIGHT -> Field.FIELD_HEIGHT
            WEIGHT -> Field.FIELD_WEIGHT
            STEPS -> Field.FIELD_STEPS
            ACTIVE_ENERGY_BURNED -> Field.FIELD_CALORIES
            HEART_RATE -> Field.FIELD_BPM
            BODY_TEMPERATURE -> HealthFields.FIELD_BODY_TEMPERATURE
            BLOOD_PRESSURE_SYSTOLIC -> HealthFields.FIELD_BLOOD_PRESSURE_SYSTOLIC
            BLOOD_PRESSURE_DIASTOLIC -> HealthFields.FIELD_BLOOD_PRESSURE_DIASTOLIC
            BLOOD_OXYGEN -> HealthFields.FIELD_OXYGEN_SATURATION
            BLOOD_GLUCOSE -> HealthFields.FIELD_BLOOD_GLUCOSE_LEVEL
            MOVE_MINUTES -> Field.FIELD_DURATION
            DISTANCE_DELTA -> Field.FIELD_DISTANCE
            NUTRIENTS -> Field.FIELD_NUTRIENTS
            else -> Field.FIELD_PERCENTAGE
        }
    }

    /// Extracts the (numeric) value from a Health Data Point
    private fun getHealthDataValue(dataPoint: DataPoint, unit: Field): Any {
        if (unit == Field.FIELD_NUTRIENTS) {
            return getNutrientsAsJsonString(dataPoint.getValue(unit))
        }

        return try {
            dataPoint.getValue(unit).asFloat()
        } catch (e1: Exception) {
            try {
                dataPoint.getValue(unit).asInt()
            } catch (e2: Exception) {
                try {
                    dataPoint.getValue(unit).asString()
                } catch (e3: Exception) {
                    Log.e("FLUTTER_HEALTH::ERROR", e3.toString())
                }
            }
        }
    }

    private fun getNutrientsAsJsonString(value: Value): String {
        var json = JSONObject()

        json.put(Field.NUTRIENT_TOTAL_FAT, value.getKeyValue(Field.NUTRIENT_TOTAL_FAT))
        json.put(Field.NUTRIENT_PROTEIN, value.getKeyValue(Field.NUTRIENT_PROTEIN))
        json.put(Field.NUTRIENT_TOTAL_CARBS, value.getKeyValue(Field.NUTRIENT_TOTAL_CARBS))

        return json.toString()
    }

    /// Called when the "getHealthDataByType" is invoked from Flutter
    private fun getData(call: MethodCall, result: Result) {
        val type = call.argument<String>("dataTypeKey")!!
        val startTime = call.argument<Long>("startDate")!!
        val endTime = call.argument<Long>("endDate")!!

        // Look up data type and unit for the type key
        val dataType = keyToHealthDataType(type)
        val unit = getUnit(type)

        println(type)

        /// Start a new thread for doing a GoogleFit data lookup
        thread {
            try {

                val fitnessOptions = callToHealthTypes(call)

                var account = GoogleSignIn.getAccountForExtension(activity, fitnessOptions)
                val response = Fitness.getHistoryClient(activity, account)
                        .readData(DataReadRequest.Builder()
                                .read(dataType)
                                .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
                                .build())

                /// Fetch all data points for the specified DataType
                val dataPoints = Tasks.await<DataReadResponse>(response).getDataSet(dataType)

                /// For each data point, extract the contents and send them to Flutter, along with date and unit.
                val healthData = dataPoints.dataPoints.mapIndexed { _, dataPoint ->
                    return@mapIndexed hashMapOf(
                            "value" to getHealthDataValue(dataPoint, unit),
                            "date_from" to dataPoint.getStartTime(TimeUnit.MILLISECONDS),
                            "date_to" to dataPoint.getEndTime(TimeUnit.MILLISECONDS),
                            "unit" to unit.toString()
                    )

                }
                activity.runOnUiThread { result.success(healthData) }
            } catch (e3: Exception) {
                Log.d("FLUTTER_HEALTH", "Failed to read data of type " + type, e3)

                activity.runOnUiThread { result.success(null) }
            }
        }
    }

    private fun callToHealthTypes(call: MethodCall): FitnessOptions {
        val typesBuilder = FitnessOptions.builder()
        val args = call.arguments as HashMap<*, *>
        for (key in args) {
            val dataType = keyToHealthDataType(key.toString())
            typesBuilder.addDataType(dataType, FitnessOptions.ACCESS_WRITE)
        }
        return typesBuilder.build()
    }

    /// Called when the "requestAuthorization" is invoked from Flutter 
    private fun requestAuthorization(call: MethodCall, result: Result) {
        val optionsToRegister = callToHealthTypes(call)
        mResult = result

        var account = GoogleSignIn.getAccountForExtension(activity, optionsToRegister)
        /// Not granted? Ask for permission
        if (!GoogleSignIn.hasPermissions(account, optionsToRegister)) {
            GoogleSignIn.requestPermissions(
                    activity,
                    GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
                    account,
                    optionsToRegister)
        }
        /// Permission already granted
        else {
            Log.d("FLUTTER_HEALTH", "Permissions already granted")
            mResult?.success(true)
        }
    }

    /// Handle calls from the MethodChannel
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestAuthorization" -> requestAuthorization(call, result)
            "getData" -> getData(call, result)
            else -> result.notImplemented()
        }
    }
}
