package com.imnexerio.revix

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.SeekBar
import android.widget.TextView
import android.view.View

class WidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    companion object {
        private const val TAG = "WidgetConfigActivity"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        fun getOpacityKey(appWidgetId: Int) = "widget_opacity_$appWidgetId"

        fun getOpacity(context: Context, appWidgetId: Int): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getInt(getOpacityKey(appWidgetId), 100)
        }

        fun getBackgroundColorWithOpacity(context: Context, appWidgetId: Int): Int {
            val opacity = getOpacity(context, appWidgetId)
            val alpha = (opacity * 255) / 100

            // Read the base widget background color from resources
            val baseColor = context.getColor(R.color.white)
            return Color.argb(alpha, Color.red(baseColor), Color.green(baseColor), Color.blue(baseColor))
        }

        fun deletePrefs(context: Context, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(getOpacityKey(appWidgetId)).apply()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set cancelled result by default (in case user backs out)
        setResult(RESULT_CANCELED)

        // Get the widget ID from the intent
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Log.e(TAG, "Invalid appWidgetId, finishing")
            finish()
            return
        }

        setContentView(R.layout.activity_widget_config)

        val seekBar = findViewById<SeekBar>(R.id.transparency_seekbar)
        val valueText = findViewById<TextView>(R.id.transparency_value_text)
        val preview = findViewById<View>(R.id.transparency_preview)
        val saveButton = findViewById<Button>(R.id.save_button)
        val cancelButton = findViewById<Button>(R.id.cancel_button)

        // Load existing opacity for this widget (default 100%)
        val currentOpacity = getOpacity(this, appWidgetId)
        seekBar.progress = currentOpacity
        valueText.text = "Opacity: $currentOpacity%"
        updatePreview(preview, currentOpacity)

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                valueText.text = "Opacity: $progress%"
                updatePreview(preview, progress)
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {}
        })

        saveButton.setOnClickListener {
            saveOpacity(seekBar.progress)
        }

        cancelButton.setOnClickListener {
            finish()
        }
    }

    private fun updatePreview(preview: View, opacity: Int) {
        val alpha = (opacity * 255) / 100
        val baseColor = getColor(R.color.white)
        preview.setBackgroundColor(
            Color.argb(alpha, Color.red(baseColor), Color.green(baseColor), Color.blue(baseColor))
        )
    }

    private fun saveOpacity(opacity: Int) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putInt(getOpacityKey(appWidgetId), opacity).apply()
        Log.d(TAG, "Saved opacity $opacity% for widget $appWidgetId")

        // Trigger a widget update so the new transparency takes effect immediately
        WidgetUpdateManager.updateAllWidgets(this)

        // Return success
        val resultValue = Intent()
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)
        finish()
    }
}
