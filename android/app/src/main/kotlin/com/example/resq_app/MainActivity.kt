package com.example.resq_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.resq_app/permissions"
    private val PERMISSION_REQUEST_CODE_CALL = 101
    private val PERMISSION_REQUEST_CODE_LOCATION = 102
    private val PERMISSION_REQUEST_CODE_ALL = 103
    
    private var pendingResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, resultChannel ->
            when (call.method) {
                "requestAllPermissions" -> {
                    pendingResult = resultChannel
                    pendingRequestCode = PERMISSION_REQUEST_CODE_ALL
                    requestAllPermissions()
                }
                "requestCallPermissions" -> {
                    pendingResult = resultChannel
                    pendingRequestCode = PERMISSION_REQUEST_CODE_CALL
                    requestCallPermissions()
                }
                "requestLocationPermissions" -> {
                    pendingResult = resultChannel
                    pendingRequestCode = PERMISSION_REQUEST_CODE_LOCATION
                    requestLocationPermissions()
                }
                "hasAllPermissions" -> {
                    resultChannel.success(hasAllPermissions())
                }
                else -> resultChannel.notImplemented()
            }
        }
    }

    private fun hasAllPermissions(): Boolean {
        return hasCallPermissions() && hasLocationPermissions()
    }

    private fun hasCallPermissions(): Boolean {
        val hasAudio = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.MODIFY_AUDIO_SETTINGS) == PackageManager.PERMISSION_GRANTED
        
        // En Android 12+, también verificar BLUETOOTH_CONNECT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return hasAudio && ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        }
        return hasAudio
    }

    private fun hasLocationPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestAllPermissions() {
        val permissionsNeeded = mutableListOf<String>()

        // Permisos de llamada
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.CAMERA)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.RECORD_AUDIO)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.MODIFY_AUDIO_SETTINGS) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.MODIFY_AUDIO_SETTINGS)
        }

        // Permisos de ubicación
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        
        // En Android 12+, también solicitar BLUETOOTH_CONNECT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }

        if (permissionsNeeded.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsNeeded.toTypedArray(), PERMISSION_REQUEST_CODE_ALL)
        } else {
            // Si todos los permisos ya están otorgados, responder inmediatamente
            pendingResult?.success(true)
            pendingResult = null
        }
    }

    private fun requestCallPermissions() {
        val permissionsNeeded = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.CAMERA)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.RECORD_AUDIO)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.MODIFY_AUDIO_SETTINGS) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.MODIFY_AUDIO_SETTINGS)
        }
        
        // En Android 12+, también solicitar BLUETOOTH_CONNECT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }

        if (permissionsNeeded.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsNeeded.toTypedArray(), PERMISSION_REQUEST_CODE_CALL)
        } else {
            // Si no hay permisos que solicitar, responder inmediatamente
            pendingResult?.success(hasCallPermissions())
            pendingResult = null
        }
    }

    private fun requestLocationPermissions() {
        val permissionsNeeded = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        if (permissionsNeeded.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsNeeded.toTypedArray(), PERMISSION_REQUEST_CODE_LOCATION)
        } else {
            // Si no hay permisos que solicitar, responder inmediatamente
            pendingResult?.success(true)
            pendingResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        
        when (requestCode) {
            PERMISSION_REQUEST_CODE_ALL -> {
                pendingResult?.success(hasAllPermissions())
            }
            PERMISSION_REQUEST_CODE_CALL -> {
                pendingResult?.success(hasCallPermissions())
            }
            PERMISSION_REQUEST_CODE_LOCATION -> {
                pendingResult?.success(hasLocationPermissions())
            }
        }
        
        pendingResult = null
        pendingRequestCode = null
    }
}
