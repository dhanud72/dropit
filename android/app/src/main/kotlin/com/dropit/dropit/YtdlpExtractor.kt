package com.dropit.dropit

import android.content.Context
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import kotlin.concurrent.thread

object YtdlpExtractor {
    private const val TAG = "DropIt"

    /**
     * Initialises youtubedl-android (Python + yt-dlp bundled inside the library).
     * This replaces the old approach of shipping a Linux ELF binary which cannot
     * run on Android's Bionic libc.
     */
    fun extract(context: Context) {
        Log.i(TAG, "[YtdlpExtractor] extract() — initialising YoutubeDL library")
        try {
            YoutubeDL.getInstance().init(context)
            Log.i(TAG, "[YtdlpExtractor] YoutubeDL.init() OK")
        } catch (e: YoutubeDLException) {
            Log.e(TAG, "[YtdlpExtractor] YoutubeDL.init() FAILED: ${e.message}", e)
            throw e
        }
        try {
            FFmpeg.getInstance().init(context)
            Log.i(TAG, "[YtdlpExtractor] FFmpeg.init() OK")
        } catch (e: Exception) {
            Log.w(TAG, "[YtdlpExtractor] FFmpeg.init() failed: ${e.message}")
        }
        // updateYoutubeDL makes a network call — run off main thread
        thread(name = "ytdlp-updater") {
            try {
                Log.i(TAG, "[YtdlpExtractor] updating yt-dlp to latest version…")
                val status = YoutubeDL.getInstance().updateYoutubeDL(context)
                Log.i(TAG, "[YtdlpExtractor] updateYoutubeDL → $status")
            } catch (e: Exception) {
                Log.w(TAG, "[YtdlpExtractor] updateYoutubeDL failed (${e.javaClass.simpleName}): ${e.message}")
            }
        }
    }

    fun getVersion(context: Context): String {
        return try {
            val v = YoutubeDL.getInstance().version(context) ?: "unknown"
            Log.i(TAG, "[YtdlpExtractor] yt-dlp version=$v")
            v
        } catch (e: Exception) {
            Log.w(TAG, "[YtdlpExtractor] getVersion failed: ${e.message}")
            "unavailable"
        }
    }
}
