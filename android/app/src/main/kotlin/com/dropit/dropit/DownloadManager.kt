package com.dropit.dropit

import android.content.Context
import android.content.Intent
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

class DownloadManager(private val context: Context) {
    private val TAG = "DropIt"
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private var eventSink: EventChannel.EventSink? = null
    private val activeCount = AtomicInteger(0)

    private fun startForegroundServiceIfNeeded() {
        if (activeCount.incrementAndGet() == 1) {
            Log.i(TAG, "[DownloadManager] starting foreground service")
            context.startForegroundService(Intent(context, DownloadService::class.java))
        }
    }

    private fun stopForegroundServiceIfDone() {
        if (activeCount.decrementAndGet() == 0) {
            Log.i(TAG, "[DownloadManager] all downloads done — stopping foreground service")
            context.stopService(Intent(context, DownloadService::class.java))
        }
    }

    val progressStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
            Log.i(TAG, "[DownloadManager] EventChannel onListen — sink attached")
            eventSink = sink
        }
        override fun onCancel(arguments: Any?) {
            Log.i(TAG, "[DownloadManager] EventChannel onCancel — sink detached")
            eventSink = null
        }
    }

    private fun emit(map: Map<String, Any?>) {
        scope.launch(Dispatchers.Main) {
            if (eventSink == null) Log.w(TAG, "[DownloadManager] emit() dropped — sink null  data=$map")
            eventSink?.success(map)
        }
    }

    fun download(
        downloadId: String,
        url: String,
        platform: String,
        quality: String,
        outputPath: String,
        isPlaylist: Boolean = false
    ) {
        Log.i(TAG, "[DownloadManager] download() START id=$downloadId platform=$platform quality=$quality isPlaylist=$isPlaylist")
        Log.i(TAG, "[DownloadManager] url=$url  outputPath=$outputPath")

        startForegroundServiceIfNeeded()

        val job = scope.launch {
            try {
            emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.0))
            val outDir = File(outputPath)
            val mkdirOk = outDir.mkdirs()
            Log.i(TAG, "[DownloadManager] mkdirs($outputPath) → $mkdirOk  exists=${outDir.exists()}")

            var lastError: Exception? = null
            for (attempt in 1..3) {
                Log.i(TAG, "[DownloadManager] attempt $attempt/3 id=$downloadId")
                try {
                    when (platform.lowercase()) {
                        "jiosaavn"  -> if (isPlaylist)
                            downloadJioSaavnPlaylist(downloadId, url, outDir)
                        else
                            downloadWithYtdlp(downloadId, url, "jiosaavn", "audio", outDir, false)
                        "spotify"   -> if (isPlaylist)
                            downloadWithYtdlp(downloadId, url, "spotify", "audio", outDir, true)
                        else
                            downloadSpotify(downloadId, url, outDir)
                        "pinterest" -> downloadPinterest(downloadId, url, outDir)
                        else        -> downloadWithYtdlp(downloadId, url, platform, quality, outDir, isPlaylist)
                    }
                    lastError = null
                    Log.i(TAG, "[DownloadManager] attempt $attempt succeeded id=$downloadId")
                    break
                } catch (e: CancellationException) {
                    Log.i(TAG, "[DownloadManager] download cancelled id=$downloadId")
                    emit(mapOf("downloadId" to downloadId, "status" to "cancelled"))
                    return@launch
                } catch (e: Exception) {
                    lastError = e
                    Log.w(TAG, "[DownloadManager] attempt $attempt FAILED id=$downloadId: ${e.message}")
                    if (attempt < 3) {
                        Log.i(TAG, "[DownloadManager] retrying in ${1500L * attempt}ms…")
                        delay(1500L * attempt)
                    }
                }
            }
            if (lastError != null) {
                Log.e(TAG, "[DownloadManager] all 3 attempts failed id=$downloadId: ${lastError.message}", lastError)
                emit(mapOf("downloadId" to downloadId, "status" to "failed",
                    "error" to (lastError.message ?: "Unknown error")))
            }
            } finally {
                stopForegroundServiceIfDone()
            }
        }
        activeJobs[downloadId] = job
    }

    private suspend fun downloadWithYtdlp(
        downloadId: String,
        url: String,
        platform: String,
        quality: String,
        outDir: File,
        isPlaylist: Boolean = false
    ) = withContext(Dispatchers.IO) {
        val isAudio = quality == "audio" ||
                      platform == "jiosaavn" || platform == "spotify"

        val request = YoutubeDLRequest(url)
        if (isPlaylist) {
            request.addOption("--yes-playlist")
            request.addOption("--newline")
            request.addOption("-o", "${outDir.absolutePath}/%(playlist_index)02d-%(title)s.%(ext)s")
        } else {
            request.addOption("--no-playlist")
            request.addOption("--newline")
            request.addOption("-o", "${outDir.absolutePath}/%(title)s.%(ext)s")
        }

        if (isAudio) {
            request.addOption("-x")
            request.addOption("--audio-format", "mp3")
            request.addOption("--audio-quality", "0")
        } else if (platform == "instagram") {
            // Instagram can be photos or videos — let yt-dlp pick format automatically.
            // Forcing bestvideo+bestaudio or --merge-output-format mp4 causes 0 items
            // for photo posts since images have no video stream.
        } else {
            val formatStr = when (quality) {
                "q1080p" -> "bestvideo[height<=1080]+bestaudio/best[height<=1080]"
                else     -> "bestvideo[height<=720]+bestaudio/best[height<=720]"
            }
            request.addOption("-f", formatStr)
            request.addOption("--merge-output-format", "mp4")
        }
        if (platform == "instagram") {
            request.addOption("--user-agent",
                "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)")
        }

        Log.i(TAG, "[yt-dlp] executing request for id=$downloadId  isAudio=$isAudio  url=$url")

        var playlistTotal = 0
        var playlistCurrent = 0
        val filesBefore = outDir.listFiles()?.size ?: 0

        YoutubeDL.getInstance().execute(request, downloadId) { progress, _, line ->
            Log.d(TAG, "[yt-dlp] $line")

            // Parse "Downloading item X of Y" for overall playlist progress
            if (line.contains("Downloading item ")) {
                val match = Regex("Downloading item (\\d+) of (\\d+)").find(line)
                if (match != null) {
                    playlistCurrent = match.groupValues[1].toIntOrNull() ?: playlistCurrent
                    playlistTotal   = match.groupValues[2].toIntOrNull() ?: playlistTotal
                }
            }

            val overallProgress = if (playlistTotal > 0) {
                ((playlistCurrent - 1) + progress / 100.0) / playlistTotal
            } else {
                progress / 100.0
            }

            emit(mapOf(
                "downloadId" to downloadId,
                "status"     to "downloading",
                "progress"   to overallProgress
            ))

            // Update title with "Song X / Y" when moving to next track
            if (playlistTotal > 0 && line.contains("Downloading item ")) {
                emit(mapOf("downloadId" to downloadId,
                    "title" to "Downloading $playlistCurrent / $playlistTotal"))
            }

            // Pick up individual track title from [download] Destination: line
            if (line.contains("[download] Destination:")) {
                val filename = line.substringAfterLast("/").substringBeforeLast(".")
                // Strip leading track number "27-Title" -> "Title"
                val title = filename.replace(Regex("^\\d+-"), "").trim()
                if (title.isNotEmpty()) emit(mapOf("downloadId" to downloadId, "title" to title))
            }
        }

        val filesAfter = outDir.listFiles()?.size ?: 0
        if (filesAfter <= filesBefore) {
            Log.w(TAG, "[yt-dlp] no files created — treating as failed (before=$filesBefore after=$filesAfter)")
            throw Exception("No files downloaded — content may require login or is unavailable")
        }
        Log.i(TAG, "[yt-dlp] SUCCESS id=$downloadId  outputPath=${outDir.absolutePath}")
        emit(mapOf("downloadId" to downloadId, "status" to "done", "progress" to 1.0,
            "outputPath" to outDir.absolutePath))
    }

    private suspend fun downloadPinterest(downloadId: String, url: String, outDir: File) =
        withContext(Dispatchers.IO) {
        Log.i(TAG, "[DownloadManager] downloadPinterest id=$downloadId url=$url")
        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.05))

        // Try yt-dlp first (video pins); capture pin ID from yt-dlp output on the way
        var capturedPinId: String? = Regex("/pin/(\\d+)").find(url)?.groupValues?.get(1)

        try {
            // Temporarily hijack progress to capture pin ID from yt-dlp output lines
            val request = com.yausername.youtubedl_android.YoutubeDLRequest(url)
            request.addOption("--no-playlist")
            request.addOption("--newline")
            request.addOption("-o", "${outDir.absolutePath}/%(title)s.%(ext)s")
            request.addOption("--merge-output-format", "mp4")
            request.addOption("--user-agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)")
            val filesBefore = outDir.listFiles()?.size ?: 0
            com.yausername.youtubedl_android.YoutubeDL.getInstance()
                .execute(request, downloadId) { progress, _, line ->
                    Log.d(TAG, "[yt-dlp] $line")
                    // Capture pin ID: "[Pinterest] 1234567: ..."
                    if (capturedPinId == null && line.contains("[Pinterest]")) {
                        Regex("\\[Pinterest\\]\\s+(\\d+):").find(line)?.groupValues?.get(1)
                            ?.let { capturedPinId = it }
                    }
                    emit(mapOf("downloadId" to downloadId, "status" to "downloading",
                        "progress" to progress / 100.0))
                }
            val filesAfter = outDir.listFiles()?.size ?: 0
            if (filesAfter > filesBefore) {
                Log.i(TAG, "[yt-dlp] Pinterest video SUCCESS")
                emit(mapOf("downloadId" to downloadId, "status" to "done", "progress" to 1.0,
                    "outputPath" to outDir.absolutePath))
                return@withContext
            }
        } catch (e: Exception) {
            if (!e.message.orEmpty().contains("No video formats")) throw e
            Log.i(TAG, "[DownloadManager] Pinterest: no video, trying image fallback pinId=$capturedPinId")
        }

        // Image fallback
        val pinId = capturedPinId ?: throw Exception("Could not extract Pinterest pin ID")

        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.2))

        // Scrape og:image from the public pin page — no auth needed
        val pinPageUrl = "https://www.pinterest.com/pin/$pinId/"
        val imageUrl = try {
            val conn = java.net.URL(pinPageUrl).openConnection() as java.net.HttpURLConnection
            conn.instanceFollowRedirects = true
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36")
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000
            conn.connect()
            val html = conn.inputStream.bufferedReader().readText()
            conn.disconnect()
            // Extract og:image content="URL"
            Regex("""<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']""")
                .find(html)?.groupValues?.get(1)
                ?: Regex("""<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']""")
                .find(html)?.groupValues?.get(1)
                ?: throw Exception("og:image not found in Pinterest page")
        } catch (e: Exception) {
            throw Exception("Pinterest image scrape failed: ${e.message}")
        }

        Log.i(TAG, "[DownloadManager] Pinterest image URL: $imageUrl")
        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.4,
            "title" to "Pinterest Image"))

        // Download the image
        val ext = imageUrl.substringAfterLast(".").substringBefore("?").lowercase()
            .let { if (it in listOf("jpg","jpeg","png","webp","gif")) it else "jpg" }
        val outFile = File(outDir, "Pinterest_$pinId.$ext")
        val conn = java.net.URL(imageUrl).openConnection() as java.net.HttpURLConnection
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 12)")
        conn.connectTimeout = 15_000
        conn.readTimeout = 30_000
        conn.connect()
        val total = conn.contentLength.toLong()
        var downloaded = 0L
        conn.inputStream.use { input ->
            outFile.outputStream().use { output ->
                val buf = ByteArray(8192)
                var n: Int
                while (input.read(buf).also { n = it } != -1) {
                    output.write(buf, 0, n)
                    downloaded += n
                    if (total > 0) {
                        val p = 0.4 + 0.6 * (downloaded.toDouble() / total)
                        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to p))
                    }
                }
            }
        }
        conn.disconnect()

        Log.i(TAG, "[DownloadManager] Pinterest image saved: ${outFile.absolutePath}")
        emit(mapOf("downloadId" to downloadId, "status" to "done", "progress" to 1.0,
            "outputPath" to outDir.absolutePath, "title" to "Pinterest_$pinId"))
    }

    private suspend fun downloadJioSaavnPlaylist(downloadId: String, url: String, outDir: File) {
        Log.i(TAG, "[DownloadManager] downloadJioSaavnPlaylist id=$downloadId url=$url")
        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.02,
            "title" to "Fetching playlist…"))

        // Detect type: album (/p/album/ or /album/) vs user playlist (/p/playlist/)
        val cleanUrl = url.lowercase().substringBefore("?")
        val apiType = when {
            cleanUrl.contains("/album/") -> "album"
            cleanUrl.contains("/featured/") -> "playlist"
            else -> "playlist"
        }
        Log.i(TAG, "[DownloadManager] JioSaavn detected type=$apiType url=$url")

        // For album/featured, try yt-dlp first — it supports these natively
        if (apiType == "album") {
            Log.i(TAG, "[DownloadManager] JioSaavn album — trying yt-dlp directly")
            try {
                downloadWithYtdlp(downloadId, url, "jiosaavn", "audio", outDir, true)
                return
            } catch (e: Exception) {
                Log.w(TAG, "[DownloadManager] yt-dlp failed for album, falling back to API: ${e.message}")
            }
        }

        // Extract token from URL: last non-empty path segment (before query params)
        val token = url.substringBefore("?").trimEnd('/').substringAfterLast("/")
        Log.i(TAG, "[DownloadManager] JioSaavn playlist token=$token")

        val apiUrl = "https://www.jiosaavn.com/api.php?__call=webapi.get&token=${java.net.URLEncoder.encode(token, "UTF-8")}&type=$apiType&n=500&p=1&_format=json&_marker=0&ctx=web6dot0"
        Log.i(TAG, "[DownloadManager] JioSaavn API url=$apiUrl")

        val json = try { httpGet(apiUrl) } catch (e: Exception) {
            throw Exception("Failed to fetch JioSaavn playlist: ${e.message}")
        }
        Log.i(TAG, "[DownloadManager] JioSaavn API response (first 300 chars): ${json.take(300)}")

        val playlistObj = try { org.json.JSONObject(json) } catch (e: Exception) {
            Log.e(TAG, "[DownloadManager] JioSaavn API returned non-JSON: ${json.take(200)}")
            throw Exception("JioSaavn API returned invalid JSON — response: ${json.take(100)}")
        }

        val songsArray = playlistObj.optJSONArray("songs")
            ?: playlistObj.optJSONArray("list")
            ?: throw Exception("No songs found in JioSaavn response (keys: ${playlistObj.keys().asSequence().toList()})")

        val total = songsArray.length()
        Log.i(TAG, "[DownloadManager] JioSaavn playlist has $total songs")
        if (total == 0) throw Exception("JioSaavn playlist is empty")

        val playlistName = playlistObj.optString("listname", "JioSaavn Playlist")
        emit(mapOf("downloadId" to downloadId, "title" to playlistName,
            "status" to "downloading", "progress" to 0.05))

        val completedCount = java.util.concurrent.atomic.AtomicInteger(0)
        val semaphore = kotlinx.coroutines.sync.Semaphore(3)

        val jobs = (0 until total).map { i ->
            scope.launch {
                semaphore.acquire()
                try {
                    val song = songsArray.getJSONObject(i)
                    val songUrl = song.optString("perma_url", "")
                    val songTitle = song.optString("song", "").ifEmpty {
                        song.optString("title", "Song ${i + 1}")
                    }

                    if (songUrl.isEmpty()) {
                        Log.w(TAG, "[DownloadManager] JioSaavn song $i has no perma_url, skipping")
                        return@launch
                    }

                    val trackIndex = "%02d".format(i + 1)
                    val request = YoutubeDLRequest(songUrl)
                    request.addOption("--no-playlist")
                    request.addOption("--newline")
                    request.addOption("-x")
                    request.addOption("--audio-format", "mp3")
                    request.addOption("--audio-quality", "0")
                    request.addOption("-o", "${outDir.absolutePath}/$trackIndex-%(title)s.%(ext)s")

                    try {
                        YoutubeDL.getInstance().execute(request, "${downloadId}_$i") { _, _, line ->
                            Log.d(TAG, "[yt-dlp] $line")
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        Log.w(TAG, "[DownloadManager] JioSaavn song ${i+1} failed: ${e.message}, continuing")
                    }

                    val done = completedCount.incrementAndGet()
                    val overall = done.toDouble() / total
                    emit(mapOf("downloadId" to downloadId, "status" to "downloading",
                        "progress" to overall, "title" to "($done/$total) $songTitle"))
                } finally {
                    semaphore.release()
                }
            }
        }
        jobs.forEach { it.join() }

        val filesAfter = outDir.listFiles()?.size ?: 0
        if (filesAfter == 0) throw Exception("No songs downloaded from JioSaavn playlist")

        Log.i(TAG, "[DownloadManager] JioSaavn playlist done, $filesAfter files")
        emit(mapOf("downloadId" to downloadId, "status" to "done", "progress" to 1.0,
            "outputPath" to outDir.absolutePath, "title" to playlistName))
    }

    private suspend fun downloadSpotify(downloadId: String, url: String, outDir: File) {
        Log.i(TAG, "[DownloadManager] downloadSpotify id=$downloadId url=$url")
        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.1))

        var searchQuery: String? = null
        try {
            val oembedUrl = "https://open.spotify.com/oembed?url=${java.net.URLEncoder.encode(url, "UTF-8")}"
            Log.i(TAG, "[DownloadManager] Spotify oEmbed GET $oembedUrl")
            val response = httpGet(oembedUrl)
            val json = JSONObject(response)
            val title = json.optString("title", "")
            val author = json.optString("author_name", "")
            Log.i(TAG, "[DownloadManager] Spotify oEmbed title='$title' author='$author'")
            if (title.isNotEmpty()) {
                val displayTitle = if (author.isNotEmpty()) "$author - $title" else title
                emit(mapOf("downloadId" to downloadId, "title" to displayTitle))
                searchQuery = if (author.isNotEmpty()) "$author $title" else title
            }
        } catch (e: Exception) {
            Log.w(TAG, "[DownloadManager] Spotify oEmbed failed, falling back to direct: ${e.message}")
        }

        emit(mapOf("downloadId" to downloadId, "status" to "downloading", "progress" to 0.2))
        val ytUrl = if (searchQuery != null) "ytsearch1:$searchQuery" else url
        Log.i(TAG, "[DownloadManager] Spotify → yt-dlp with '$ytUrl'")
        downloadWithYtdlp(downloadId, ytUrl, "spotify", "audio", outDir)
    }

    fun fetchTitle(url: String, platform: String): String {
        Log.d(TAG, "[DownloadManager] fetchTitle platform=$platform url=$url")
        return try {
            val request = YoutubeDLRequest(url)
            request.addOption("--get-title")
            // For playlists, fetch only the first item to get the playlist name fast
            if (url.contains("playlist?list=") || (url.contains("list=") && !url.contains("watch?v="))) {
                request.addOption("--playlist-items", "1")
            } else {
                request.addOption("--no-playlist")
            }
            val response = YoutubeDL.getInstance().execute(request)
            val result = response.out.trim().lines().firstOrNull() ?: ""
            Log.d(TAG, "[DownloadManager] fetchTitle → '$result'")
            result
        } catch (e: Exception) {
            Log.w(TAG, "[DownloadManager] fetchTitle error: ${e.message}")
            ""
        }
    }

    fun fetchThumbnail(url: String, platform: String): String {
        Log.d(TAG, "[DownloadManager] fetchThumbnail platform=$platform url=$url")
        return try {
            val request = YoutubeDLRequest(url)
            request.addOption("--get-thumbnail")
            if (url.contains("playlist?list=") || (url.contains("list=") && !url.contains("watch?v="))) {
                request.addOption("--playlist-items", "1")
            } else {
                request.addOption("--no-playlist")
            }
            val response = YoutubeDL.getInstance().execute(request)
            val result = response.out.trim().lines().firstOrNull() ?: ""
            Log.d(TAG, "[DownloadManager] fetchThumbnail → '$result'")
            result
        } catch (e: Exception) {
            Log.w(TAG, "[DownloadManager] fetchThumbnail error: ${e.message}")
            ""
        }
    }

    fun cancel(downloadId: String) {
        Log.i(TAG, "[DownloadManager] cancel id=$downloadId")
        try {
            YoutubeDL.getInstance().destroyProcessById(downloadId)
        } catch (e: Exception) {
            Log.w(TAG, "[DownloadManager] cancel error: ${e.message}")
        }
        activeJobs[downloadId]?.cancel()
        activeJobs.remove(downloadId)
    }

    private fun httpGet(url: String): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36")
        try {
            connection.connect()
            return connection.inputStream.bufferedReader().readText()
        } finally {
            connection.disconnect()
        }
    }
}
