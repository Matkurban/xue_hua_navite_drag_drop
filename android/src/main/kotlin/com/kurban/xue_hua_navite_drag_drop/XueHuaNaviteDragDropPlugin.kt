package com.kurban.xue_hua_navite_drag_drop

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Point
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.DragEvent
import android.view.View
import android.widget.ImageView
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream

/** XueHuaNaviteDragDropPlugin */
class XueHuaNaviteDragDropPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var dragListenerAttached = false
    private var allowDrop = true

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "xue_hua_navite_drag_drop")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "initDragDrop" -> {
                attachDragListenerIfNeeded()
                result.success(null)
            }
            "setDropEffect" -> {
                val op = call.argument<String>("operation") ?: "copy"
                allowDrop = op != "none"
                result.success(null)
            }
            "startDragOut" -> {
                attachDragListenerIfNeeded()
                val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                if (items.isEmpty()) {
                    result.success(false)
                    return
                }
                handleStartDragOut(items, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun attachDragListenerIfNeeded() {
        val act = activity ?: return
        if (dragListenerAttached) return
        val rootView = act.window?.decorView ?: return
        val density = act.resources.displayMetrics.density.coerceAtLeast(1.0f)

        rootView.setOnDragListener { _, event ->
            val logicalX = (event.x / density).toDouble()
            val logicalY = (event.y / density).toDouble()
            when (event.action) {
                DragEvent.ACTION_DRAG_STARTED -> true
                DragEvent.ACTION_DRAG_ENTERED -> {
                    channel.invokeMethod("onDragEntered", mapOf("x" to logicalX, "y" to logicalY))
                    true
                }
                DragEvent.ACTION_DRAG_LOCATION -> {
                    channel.invokeMethod("onDragUpdated", mapOf("x" to logicalX, "y" to logicalY))
                    true
                }
                DragEvent.ACTION_DRAG_EXITED -> {
                    channel.invokeMethod("onDragExited", null)
                    true
                }
                DragEvent.ACTION_DROP -> {
                    if (!allowDrop) {
                        false
                    } else {
                        val dropPermissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            act.requestDragAndDropPermissions(event)
                        } else {
                            null
                        }
                        try {
                            val items = extractClipDataItems(act, event.clipData)
                            channel.invokeMethod(
                                "onPerformDrop",
                                mapOf(
                                    "x" to logicalX,
                                    "y" to logicalY,
                                    "items" to items
                                )
                            )
                        } finally {
                            dropPermissions?.release()
                        }
                        true
                    }
                }
                DragEvent.ACTION_DRAG_ENDED -> {
                    channel.invokeMethod("onDragExited", null)
                    true
                }
                else -> false
            }
        }
        dragListenerAttached = true
    }

    private fun extractClipDataItems(act: Activity, clipData: ClipData?): List<Map<String, Any?>> {
        if (clipData == null) return emptyList()
        val results = mutableListOf<Map<String, Any?>>()
        val dropCacheDir = File(act.cacheDir, "xue_hua_drop_${System.currentTimeMillis()}").apply {
            mkdirs()
        }

        for (i in 0 until clipData.itemCount) {
            val uri = clipData.getItemAt(i).uri ?: continue
            if (uri.scheme == "file") {
                val path = uri.path ?: continue
                results.add(serializeLocalFile(File(path), 0))
            } else if (uri.scheme == "content") {
                val itemMap = copyContentUriToCache(act, uri, dropCacheDir)
                if (itemMap != null) {
                    results.add(itemMap)
                }
            }
        }
        return results
    }

    private fun serializeLocalFile(file: File, depth: Int): Map<String, Any?> {
        val isDir = file.isDirectory
        var totalSize = if (isDir) 0L else file.length()
        val children = mutableListOf<Map<String, Any?>>()

        if (isDir && depth < 3) {
            file.listFiles()?.forEach { child ->
                if (!child.name.startsWith(".")) {
                    val serializedChild = serializeLocalFile(child, depth + 1)
                    totalSize += (serializedChild["size"] as? Long) ?: 0L
                    children.add(serializedChild)
                }
            }
        }

        return mapOf(
            "name" to file.name,
            "path" to file.absolutePath,
            "uri" to Uri.fromFile(file).toString(),
            "isDirectory" to isDir,
            "size" to totalSize,
            "children" to children
        )
    }

    private fun copyContentUriToCache(
        act: Activity,
        uri: Uri,
        destDir: File
    ): Map<String, Any?>? {
        val resolver = act.contentResolver
        val mimeType = resolver.getType(uri)
        val isTree = DocumentsContract.isTreeUri(uri) ||
            mimeType == DocumentsContract.Document.MIME_TYPE_DIR

        var displayName = uri.lastPathSegment?.substringAfterLast('/') ?: "dropped_file"
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) {
                    displayName = cursor.getString(idx) ?: displayName
                }
            }
        }

        if (isTree) {
            val folder = File(destDir, displayName).apply { mkdirs() }
            return mapOf(
                "name" to displayName,
                "path" to folder.absolutePath,
                "uri" to uri.toString(),
                "isDirectory" to true,
                "size" to 0L,
                "mimeType" to mimeType,
                "children" to emptyList<Map<String, Any?>>()
            )
        }

        val targetFile = File(destDir, displayName)
        return try {
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            mapOf(
                "name" to displayName,
                "path" to targetFile.absolutePath,
                "uri" to uri.toString(),
                "isDirectory" to false,
                "size" to targetFile.length(),
                "mimeType" to mimeType,
                "children" to emptyList<Map<String, Any?>>()
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun handleStartDragOut(items: List<Map<String, Any?>>, result: Result) {
        val act = activity
        val rootView = act?.window?.decorView
        if (act == null || rootView == null) {
            result.success(false)
            return
        }

        val resolvedFiles = mutableListOf<File>()
        val pendingAsync = mutableListOf<Map<String, Any?>>()

        for (item in items) {
            val isAsync = (item["isAsync"] as? Boolean) ?: false
            val filePath = item["filePath"] as? String
            if (!isAsync && !filePath.isNullOrEmpty()) {
                resolvedFiles.add(File(filePath))
            } else {
                pendingAsync.add(item)
            }
        }

        val previewBytes = items.firstOrNull()?.get("previewImage") as? ByteArray

        if (pendingAsync.isEmpty()) {
            val started = startAndroidDragWithFiles(act, rootView, resolvedFiles, previewBytes)
            result.success(started)
            return
        }

        val exportDir = File(act.cacheDir, "xue_hua_drag_out").apply { mkdirs() }
        var remaining = pendingAsync.size

        for (asyncItem in pendingAsync) {
            val id = asyncItem["id"] as? String ?: ""
            val fileName = asyncItem["fileName"] as? String ?: "exported_file"
            val targetFile = File(exportDir, fileName)

            channel.invokeMethod(
                "onRequestAsyncFileWrite",
                mapOf(
                    "id" to id,
                    "destinationPath" to targetFile.absolutePath
                ),
                object : Result {
                    override fun success(res: Any?) {
                        if (res == true && targetFile.exists()) {
                            resolvedFiles.add(targetFile)
                        }
                        remaining--
                        if (remaining == 0) {
                            startAndroidDragWithFiles(act, rootView, resolvedFiles, previewBytes)
                        }
                    }

                    override fun error(code: String, msg: String?, details: Any?) {
                        remaining--
                        if (remaining == 0) {
                            startAndroidDragWithFiles(act, rootView, resolvedFiles, previewBytes)
                        }
                    }

                    override fun notImplemented() {
                        remaining--
                        if (remaining == 0) {
                            startAndroidDragWithFiles(act, rootView, resolvedFiles, previewBytes)
                        }
                    }
                }
            )
        }
        result.success(true)
    }

    private fun startAndroidDragWithFiles(
        act: Activity,
        rootView: View,
        files: List<File>,
        previewBytes: ByteArray?
    ): Boolean {
        if (files.isEmpty()) {
            channel.invokeMethod("onDragOutEnded", mapOf("success" to false))
            return false
        }
        val authority = "${act.packageName}.xue_hua_drag_drop.provider"
        var clipData: ClipData? = null

        for (file in files) {
            if (!file.exists()) continue
            val uri = FileProvider.getUriForFile(act, authority, file)
            if (clipData == null) {
                clipData = ClipData(
                    file.name,
                    arrayOf(ClipDescription.MIMETYPE_TEXT_URILIST),
                    ClipData.Item(uri)
                )
            } else {
                clipData.addItem(ClipData.Item(uri))
            }
        }

        if (clipData == null) {
            channel.invokeMethod("onDragOutEnded", mapOf("success" to false))
            return false
        }

        val shadowBuilder = createShadowBuilder(act, rootView, previewBytes)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            View.DRAG_FLAG_GLOBAL or View.DRAG_FLAG_GLOBAL_URI_READ
        } else {
            0
        }

        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            rootView.startDragAndDrop(clipData, shadowBuilder, null, flags)
        } else {
            @Suppress("DEPRECATION")
            rootView.startDrag(clipData, shadowBuilder, null, flags)
        }
        channel.invokeMethod("onDragOutEnded", mapOf("success" to started))
        return started
    }

    private fun createShadowBuilder(
        act: Activity,
        fallbackView: View,
        previewBytes: ByteArray?
    ): View.DragShadowBuilder {
        if (previewBytes != null && previewBytes.isNotEmpty()) {
            val bitmap = BitmapFactory.decodeByteArray(previewBytes, 0, previewBytes.size)
            if (bitmap != null) {
                return object : View.DragShadowBuilder() {
                    override fun onProvideShadowMetrics(outShadowSize: Point, outShadowTouchPoint: Point) {
                        val width = bitmap.width.coerceAtMost(320)
                        val height = bitmap.height.coerceAtMost(320)
                        outShadowSize.set(width, height)
                        outShadowTouchPoint.set(width / 2, height / 2)
                    }

                    override fun onDrawShadow(canvas: Canvas) {
                        canvas.drawBitmap(bitmap, 0f, 0f, null)
                    }
                }
            }
        }
        val iconView = ImageView(act)
        return View.DragShadowBuilder(iconView.takeIf { it.width > 0 } ?: fallbackView)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        dragListenerAttached = false
        attachDragListenerIfNeeded()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        dragListenerAttached = false
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        dragListenerAttached = false
        attachDragListenerIfNeeded()
    }

    override fun onDetachedFromActivity() {
        activity = null
        dragListenerAttached = false
    }
}
