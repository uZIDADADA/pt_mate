package com.github.justlookatnow.ptmate

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.security.MessageDigest

internal object ForkUpdateInstaller {
    private fun signingDigests(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
        return signatures?.map {
            MessageDigest.getInstance("SHA-256").digest(it.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
        }?.toSet().orEmpty()
    }

    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }

    fun install(activity: Activity, path: String, checksum: String, expectedBuild: Long): Boolean {
        val directory = File(activity.cacheDir, "pt_mate_updates").canonicalFile
        val apk = File(path).canonicalFile
        require(apk.parentFile == directory && apk.name == "update.apk" && apk.isFile) {
            "Untrusted update file"
        }
        require(checksum.matches(Regex("[a-f0-9]{64}"))) { "Invalid checksum" }
        val digest = MessageDigest.getInstance("SHA-256")
        apk.inputStream().use { stream ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
        require(actual == checksum) { "APK checksum mismatch" }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        @Suppress("DEPRECATION")
        val candidate = activity.packageManager.getPackageArchiveInfo(apk.path, flags)
            ?: error("Invalid APK")
        @Suppress("DEPRECATION")
        val installed = activity.packageManager.getPackageInfo(activity.packageName, flags)
        require(candidate.packageName == activity.packageName) { "Wrong application" }
        require(versionCode(candidate) == expectedBuild && expectedBuild > versionCode(installed)) {
            "Update must increase versionCode"
        }
        val signers = signingDigests(candidate)
        require(signers.isNotEmpty() && signers == signingDigests(installed)) {
            "APK signing certificate mismatch"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}")))
            return false
        }
        val uri = FileProvider.getUriForFile(activity,
            "${activity.packageName}.fork_updates", apk)
        activity.startActivity(Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
        return true
    }
}
