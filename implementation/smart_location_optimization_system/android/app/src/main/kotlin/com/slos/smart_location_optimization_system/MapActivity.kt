package com.slos.smart_location_optimization_system

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.preference.PreferenceManager
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import org.osmdroid.views.overlay.gestures.RotationGestureOverlay

class MapActivity : AppCompatActivity() {

    private val REQUEST_PERMISSIONS_REQUEST_CODE = 1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Load OSMDroid configuration
        val ctx = applicationContext
        Configuration.getInstance().load(ctx, PreferenceManager.getDefaultSharedPreferences(ctx))

        // Use view binding for modern UI interactions
        // Note: You might need to enable viewBinding in build.gradle.kts
        // For simplicity, we can use findViewById if viewBinding is not set up
        setContentView(R.layout.activity_map)

        setupMap()
        setupUI()
        checkPermissions()
    }

    private fun setupMap() {
        val map = findViewById<org.osmdroid.views.MapView>(R.id.map)
        map.setTileSource(TileSourceFactory.MAPNIK)
        
        // Map controls
        map.setMultiTouchControls(true)
        map.zoomController.setVisibility(CustomZoomButtonsController.Visibility.ALWAYS)
        
        // Smooth panning and zoom
        map.controller.setZoom(15.0)
        
        // Default location: Lahore, Pakistan
        val startPoint = GeoPoint(31.5204, 74.3587)
        map.controller.setCenter(startPoint)

        // Add custom marker
        val startMarker = Marker(map)
        startMarker.position = startPoint
        startMarker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
        startMarker.title = "Recommended Business Location"
        startMarker.snippet = "High suitability score based on AI analysis."
        map.overlays.add(startMarker)

        // Add Rotation Gesture
        val rotationGestureOverlay = RotationGestureOverlay(map)
        rotationGestureOverlay.isEnabled = true
        map.overlays.add(rotationGestureOverlay)

        // Heatmap Overlay Placeholder
        addHeatmapPlaceholder(map)
        
        map.invalidate()
    }

    private fun setupUI() {
        // Handle chips selection
        // In a real app, this would trigger /predict or /heatmap-data API
        findViewById<com.google.android.material.chip.Chip>(R.id.chipCafes).setOnClickListener {
            Toast.makeText(this, "Fetching AI data for Cafes...", Toast.LENGTH_SHORT).show()
        }

        findViewById<android.widget.Button>(R.id.btnOptimize).setOnClickListener {
            Toast.makeText(this, "Running /optimize API call...", Toast.LENGTH_LONG).show()
            // Transition placeholder for AI results
        }

        findViewById<com.google.android.material.floatingactionbutton.FloatingActionButton>(R.id.fabMyLocation).setOnClickListener {
            Toast.makeText(this, "Locating your position...", Toast.LENGTH_SHORT).show()
        }
    }

    private fun addHeatmapPlaceholder(map: org.osmdroid.views.MapView) {
        // Using a Polygon to simulate a heatmap zone for FYP demo
        val circlePoints = ArrayList<GeoPoint>()
        val center = GeoPoint(31.5204, 74.3587)
        for (f in 0 until 360 step 10) {
            circlePoints.add(center.destinationPoint(500.0, f.toDouble()))
        }
        val zone = Polygon()
        zone.points = circlePoints
        zone.fillPaint.color = 0x33FF0000 // Transparent Red
        zone.outlinePaint.color = 0xFFFF0000.toInt()
        zone.title = "High Demand Zone"
        map.overlays.add(zone)
    }

    private fun checkPermissions() {
        val permissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )
        val permissionsToRequest = ArrayList<String>()
        for (permission in permissions) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(permission)
            }
        }
        if (permissionsToRequest.size > 0) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                REQUEST_PERMISSIONS_REQUEST_CODE
            )
        }
    }

    override fun onResume() {
        super.onResume()
        findViewById<org.osmdroid.views.MapView>(R.id.map).onResume()
    }

    override fun onPause() {
        super.onPause()
        findViewById<org.osmdroid.views.MapView>(R.id.map).onPause()
    }
}
