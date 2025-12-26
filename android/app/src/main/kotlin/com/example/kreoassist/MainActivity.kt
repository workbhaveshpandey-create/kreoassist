package com.example.kreoassist

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kreoassist/sms"
    private val SMS_PERMISSION_CODE = 100
    private val CALL_PERMISSION_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    
                    if (phone != null && message != null) {
                        if (checkSmsPermission()) {
                            sendSMS(phone, message)
                            result.success(true)
                        } else {
                            requestSmsPermission()
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone or message is null", null)
                    }
                }
                "directCall" -> {
                    val phone = call.argument<String>("phone")
                    if (phone != null) {
                        if (checkCallPermission()) {
                            makeDirectCall(phone)
                            result.success(true)
                        } else {
                            requestCallPermission()
                            result.error("PERMISSION_DENIED", "Call permission not granted", null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone is null", null)
                    }
                }
                "checkPermission" -> {
                    result.success(checkSmsPermission())
                }
                "checkCallPermission" -> {
                    result.success(checkCallPermission())
                }
                "requestPermission" -> {
                    requestSmsPermission()
                    requestCallPermission()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun checkSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun checkCallPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_CODE)
    }
    
    private fun requestCallPermission() {
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CALL_PHONE), CALL_PERMISSION_CODE)
    }
    
    private fun sendSMS(phone: String, message: String) {
        try {
            val smsManager = SmsManager.getDefault()
            // Split message if too long
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun makeDirectCall(phone: String) {
        try {
            val callIntent = Intent(Intent.ACTION_CALL)
            callIntent.data = Uri.parse("tel:$phone")
            startActivity(callIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
