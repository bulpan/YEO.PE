package com.yeope.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class YeopeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize other libs here (e.g. loggers)
    }
}
