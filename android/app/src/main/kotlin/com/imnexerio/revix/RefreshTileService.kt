package com.imnexerio.revix

import android.content.Intent
import android.service.quicksettings.TileService
import android.util.Log

class RefreshTileService : TileService() {

    companion object {
        private const val TAG = "RefreshTileService"
    }

    override fun onClick() {
        super.onClick()
        Log.d(TAG, "Tile clicked, triggering refresh")

        val refreshIntent = Intent(applicationContext, TodayWidget::class.java)
        refreshIntent.action = TodayWidget.ACTION_REFRESH
        applicationContext.sendBroadcast(refreshIntent)
    }
}
