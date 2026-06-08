package com.dropit.dropit

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val TAG = "DropIt"
    private val channelName = "com.dropit/downloader"
    private val progressChannelName = "com.dropit/progress"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "[MainActivity] onCreate — intent action=${intent?.action}  type=${intent?.type}")
        logIntent(intent, "onCreate")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.i(TAG, "[MainActivity] onNewIntent — action=${intent.action}  type=${intent.type}")
        logIntent(intent, "onNewIntent")
    }

    private fun logIntent(intent: Intent?, label: String) {
        if (intent == null) { Log.i(TAG, "[$label] intent is null"); return }
        Log.i(TAG, "[$label] action=${intent.action}")
        Log.i(TAG, "[$label] type=${intent.type}")
        Log.i(TAG, "[$label] scheme=${intent.scheme}")
        Log.i(TAG, "[$label] data=${intent.data}")
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            Log.i(TAG, "[$label] EXTRA_TEXT='$sharedText'")
            Log.i(TAG, "[$label] EXTRA_SUBJECT='$sharedSubject'")
            if (sharedText != null) {
                val platform = detectPlatform(sharedText)
                Log.i(TAG, "[$label] detected platform='$platform' for url='$sharedText'")
            }
        }
        val extras = intent.extras
        if (extras != null) {
            for (key in extras.keySet()) {
                Log.d(TAG, "[$label] extra[$key]=${extras.get(key)}")
            }
        }
    }

    private fun detectPlatform(url: String): String {
        val lower = url.lowercase()
        return when {
            lower.contains("youtube.com") || lower.contains("youtu.be") -> "youtube"
            lower.contains("instagram.com") -> "instagram"
            lower.contains("pinterest.com") || lower.contains("pin.it") -> "pinterest"
            lower.contains("threads.net") -> "threads"
            lower.contains("jiosaavn.com") || lower.contains("saavn.com") -> "jiosaavn"
            lower.contains("spotify.com") -> "spotify"
            else -> "unknown"
        }
    }

    private fun openFileOrFolder(path: String) {
        val file = File(path)
        if (!file.exists()) throw Exception("Path does not exist: $path")

        // If it's a directory, find the most recently modified file inside it
        val target = if (file.isDirectory) {
            file.listFiles()
                ?.filter { it.isFile }
                ?.maxByOrNull { it.lastModified() }
                ?: throw Exception("No files in folder: $path")
        } else {
            file
        }

        val ext = target.extension.lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
        val uri: Uri = FileProvider.getUriForFile(
            this, "${packageName}.provider", target
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(Intent.createChooser(intent, "Open with"))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "[MainActivity] configureFlutterEngine — setting up MethodChannel '$channelName'")

        val downloader = DownloadManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "[MethodChannel] received method='${call.method}'")
                when (call.method) {
                    "extractYtdlp" -> {
                        Log.i(TAG, "[MethodChannel] extractYtdlp called")
                        try {
                            YtdlpExtractor.extract(this)
                            val version = YtdlpExtractor.getVersion(this)
                            Log.i(TAG, "[MethodChannel] extractYtdlp OK — version='$version'")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "[MethodChannel] extractYtdlp FAILED: ${e.message}", e)
                            result.error("EXTRACT_FAILED", e.message, null)
                        }
                    }
                    "getYtdlpVersion" -> {
                        val version = YtdlpExtractor.getVersion(this)
                        Log.i(TAG, "[MethodChannel] getYtdlpVersion → '$version'")
                        result.success(version)
                    }
                    "downloadMedia" -> {
                        val downloadId = call.argument<String>("downloadId") ?: ""
                        val url = call.argument<String>("url") ?: ""
                        val platform = call.argument<String>("platform") ?: ""
                        val quality = call.argument<String>("quality") ?: "q720p"
                        val outputPath = call.argument<String>("outputPath") ?: ""
                        val isPlaylist = call.argument<Boolean>("isPlaylist") ?: false
                        Log.i(TAG, "[MethodChannel] downloadMedia id=$downloadId platform=$platform quality=$quality isPlaylist=$isPlaylist")
                        Log.i(TAG, "[MethodChannel] downloadMedia url=$url")
                        Log.i(TAG, "[MethodChannel] downloadMedia outputPath=$outputPath")
                        downloader.download(downloadId, url, platform, quality, outputPath, isPlaylist)
                        result.success(downloadId)
                    }
                    "cancelDownload" -> {
                        val downloadId = call.argument<String>("downloadId") ?: ""
                        Log.i(TAG, "[MethodChannel] cancelDownload id=$downloadId")
                        downloader.cancel(downloadId)
                        result.success(null)
                    }
                    "fetchTitle" -> {
                        val url = call.argument<String>("url") ?: ""
                        val platform = call.argument<String>("platform") ?: ""
                        Log.d(TAG, "[MethodChannel] fetchTitle platform=$platform url=$url")
                        CoroutineScope(Dispatchers.IO).launch {
                            val title = downloader.fetchTitle(url, platform)
                            Log.d(TAG, "[MethodChannel] fetchTitle → '$title'")
                            withContext(Dispatchers.Main) { result.success(title) }
                        }
                    }
                    "fetchThumbnail" -> {
                        val url = call.argument<String>("url") ?: ""
                        val platform = call.argument<String>("platform") ?: ""
                        Log.d(TAG, "[MethodChannel] fetchThumbnail platform=$platform url=$url")
                        CoroutineScope(Dispatchers.IO).launch {
                            val thumb = downloader.fetchThumbnail(url, platform)
                            Log.d(TAG, "[MethodChannel] fetchThumbnail → '$thumb'")
                            withContext(Dispatchers.Main) { result.success(thumb) }
                        }
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        Log.i(TAG, "[MethodChannel] openFile path=$path")
                        try {
                            openFileOrFolder(path)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "[MethodChannel] openFile error: ${e.message}", e)
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    else -> {
                        Log.w(TAG, "[MethodChannel] notImplemented: ${call.method}")
                        result.notImplemented()
                    }
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, progressChannelName)
            .setStreamHandler(downloader.progressStreamHandler)
        Log.i(TAG, "[MainActivity] EventChannel '$progressChannelName' registered")
    }
}
