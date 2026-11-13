package io.github.lucasbritosilva.aplicativoall

import android.annotation.TargetApi
import android.app.AlarmManager
import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Atividade única do app. Além do Flutter, atende o canal
 * `aplicativo_all/native` (links, discador, cofre e uso de apps).
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "aplicativo_all/native"
        private const val REQUEST_DEVICE_CREDENTIAL = 4101
        private const val REQUEST_PICK_IMAGES = 4102
        private const val NOTE_IMAGES_DIR = "note_images"
    }

    private val vault by lazy { VaultCrypto(applicationContext) }
    private val background = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingUnlock: MethodChannel.Result? = null
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handle)
    }

    override fun onDestroy() {
        vault.lock()
        background.shutdown()
        super.onDestroy()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openUrl" -> result.success(openUrl(call.argument<String>("url") ?: ""))
            "dial" -> result.success(dial(call.argument<String>("phone") ?: ""))
            "copySensitive" -> {
                copySensitive(call.argument<String>("text") ?: "")
                result.success(null)
            }
            "setSecure" -> {
                if (call.argument<Boolean>("enabled") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }

            "vaultState" -> result.success(vault.state())
            "vaultUnlock" -> vaultUnlock(result)
            "vaultLock" -> {
                vault.lock()
                result.success(null)
            }
            "vaultReset" -> {
                vault.reset()
                result.success(null)
            }
            "vaultEncrypt" -> result.success(vault.encrypt(call.argument<String>("plain") ?: ""))
            "vaultDecryptAll" -> {
                val payloads = call.argument<List<String>>("payloads") ?: emptyList()
                result.success(payloads.map { vault.decrypt(it) })
            }

            "pickImages" -> pickImages(result)
            "deleteFiles" -> {
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                background.execute {
                    for (path in paths) deleteNoteImage(path)
                    main.post { result.success(null) }
                }
            }

            "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
            "openExactAlarmSettings" -> result.success(openExactAlarmSettings())

            "hasUsageAccess" -> result.success(UsageStatsHelper.hasAccess(this))
            "openUsageAccessSettings" -> {
                openSettings(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                result.success(null)
            }
            "canDrawOverlays" -> result.success(
                Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this),
            )
            "openOverlaySettings" -> {
                openSettings(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ),
                )
                result.success(null)
            }
            "installedApps" -> background.execute {
                val apps = installedApps()
                main.post { result.success(apps) }
            }
            "usageToday" -> background.execute {
                val usage = try {
                    UsageStatsHelper.usageToday(this)
                } catch (e: Exception) {
                    emptyMap()
                }
                main.post { result.success(usage) }
            }
            "configureMonitor" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                val limits = call.argument<Map<String, Int>>("limits") ?: emptyMap()
                val modes = call.argument<Map<String, String>>("modes") ?: emptyMap()
                UsageMonitorService.saveConfig(this, enabled, limits, modes)
                if (enabled) {
                    result.success(UsageMonitorService.start(this))
                } else {
                    UsageMonitorService.stop(this)
                    result.success(true)
                }
            }
            "monitorRunning" -> result.success(UsageMonitorService.running)
            else -> result.notImplemented()
        }
    }

    // ---- Alarmes exatos ----

    /**
     * Android 11 ou anterior: sempre permitido. Android 12: depende da
     * permissão SCHEDULE_EXACT_ALARM, que o usuário liga na tela "Alarmes e
     * lembretes". Android 13+: o app usa USE_EXACT_ALARM, concedida na
     * instalação, e o AlarmManager responde verdadeiro.
     */
    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    /** Abre a tela "Alarmes e lembretes" do app. Falso se não existir. */
    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        val intent = Intent(
            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
            Uri.parse("package:$packageName"),
        )
        if (start(intent)) return true
        return start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }

    // ---- Links e telefone (só abrem o app; nada é enviado sozinho) ----

    private fun openUrl(url: String): Boolean {
        val uri = Uri.parse(url)
        if (uri.scheme != "https" && uri.scheme != "http") return false
        return start(Intent(Intent.ACTION_VIEW, uri))
    }

    private fun dial(phone: String): Boolean {
        val clean = phone.filter { it.isDigit() || it == '+' }
        if (clean.isEmpty()) return false
        return start(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$clean")))
    }

    private fun start(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        false
    } catch (e: SecurityException) {
        false
    }

    private fun openSettings(intent: Intent) {
        if (!start(intent)) {
            start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        }
    }

    private fun copySensitive(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("BrutAll", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        clipboard.setPrimaryClip(clip)
    }

    // ---- Cofre ----

    private fun vaultUnlock(result: MethodChannel.Result) {
        if (!vault.isDeviceSecure()) {
            result.success("no_lock_screen")
            return
        }
        if (pendingUnlock != null) {
            result.success("canceled")
            return
        }
        try {
            vault.ensureKey()
        } catch (e: Exception) {
            result.success("error")
            return
        }
        pendingUnlock = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            showBiometricPrompt()
        } else {
            showDeviceCredential()
        }
    }

    private fun finishUnlock(outcome: String) {
        val r = pendingUnlock ?: return
        pendingUnlock = null
        r.success(outcome)
    }

    @TargetApi(Build.VERSION_CODES.P)
    private fun showBiometricPrompt() {
        val builder = BiometricPrompt.Builder(this)
            .setTitle("Abrir o cofre")
            .setSubtitle("Use a digital, o rosto ou o bloqueio de tela")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(
                android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL,
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setDeviceCredentialAllowed(true)
        }
        val prompt = try {
            builder.build()
        } catch (e: Exception) {
            finishUnlock("error")
            return
        }
        prompt.authenticate(
            CancellationSignal(),
            mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult?) {
                    finishUnlock(vault.afterAuthentication())
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                    finishUnlock(
                        if (errorCode == BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED ||
                            errorCode == BiometricPrompt.BIOMETRIC_ERROR_CANCELED
                        ) {
                            "canceled"
                        } else {
                            "error"
                        },
                    )
                }
            },
        )
    }

    @Suppress("DEPRECATION")
    private fun showDeviceCredential() {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val intent = km.createConfirmDeviceCredentialIntent(
            "Abrir o cofre",
            "Confirme o bloqueio de tela do celular",
        )
        if (intent == null) {
            finishUnlock("no_lock_screen")
            return
        }
        startActivityForResult(intent, REQUEST_DEVICE_CREDENTIAL)
    }

    @Deprecated("Usado para o seletor de imagens e, no Android 8 ou anterior, para o bloqueio de tela.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PICK_IMAGES) {
            onImagesPicked(if (resultCode == RESULT_OK) data else null)
            return
        }
        if (requestCode == REQUEST_DEVICE_CREDENTIAL) {
            finishUnlock(if (resultCode == RESULT_OK) vault.afterAuthentication() else "canceled")
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    // ---- Imagens das notas ----

    /**
     * Abre o seletor de fotos do Android (no 13+ o seletor do sistema, que
     * não exige permissão de armazenamento). As imagens escolhidas são
     * copiadas para a pasta privada do app; devolve os caminhos das cópias.
     */
    private fun pickImages(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(emptyList<String>())
            return
        }
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(android.provider.MediaStore.ACTION_PICK_IMAGES)
                .setType("image/*")
                .putExtra(android.provider.MediaStore.EXTRA_PICK_IMAGES_MAX, 10)
        } else {
            Intent(Intent.ACTION_GET_CONTENT)
                .setType("image/*")
                .addCategory(Intent.CATEGORY_OPENABLE)
                .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        pendingPick = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_PICK_IMAGES)
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            result.success(emptyList<String>())
        }
    }

    private fun onImagesPicked(data: Intent?) {
        val r = pendingPick ?: return
        pendingPick = null
        val uris = ArrayList<Uri>()
        val clip = data?.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let(uris::add)
        } else {
            data?.data?.let(uris::add)
        }
        if (uris.isEmpty()) {
            r.success(emptyList<String>())
            return
        }
        background.execute {
            val paths = uris.mapNotNull { copyNoteImage(it) }
            main.post { r.success(paths) }
        }
    }

    private fun noteImagesDir(): java.io.File =
        java.io.File(filesDir, NOTE_IMAGES_DIR).apply { mkdirs() }

    private fun copyNoteImage(uri: Uri): String? = try {
        val type = contentResolver.getType(uri) ?: "image/jpeg"
        val ext = when {
            type.endsWith("png") -> "png"
            type.endsWith("webp") -> "webp"
            type.endsWith("gif") -> "gif"
            else -> "jpg"
        }
        val file = java.io.File(noteImagesDir(), "${java.util.UUID.randomUUID()}.$ext")
        contentResolver.openInputStream(uri)?.use { input ->
            file.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        file.absolutePath
    } catch (e: Exception) {
        null
    }

    /** Só apaga arquivos dentro da pasta de imagens das notas. */
    private fun deleteNoteImage(path: String) {
        try {
            val dir = noteImagesDir().canonicalFile
            val file = java.io.File(path).canonicalFile
            if (file.parentFile == dir) file.delete()
        } catch (e: Exception) {
            // Arquivo já apagado ou caminho inválido.
        }
    }

    // ---- Apps instalados ----

    private fun installedApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val activities = pm.queryIntentActivities(launcher, 0)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        for (info in activities) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seen.add(pkg)) continue
            val label = try {
                info.loadLabel(pm).toString()
            } catch (e: Exception) {
                pkg
            }
            out.add(mapOf("package" to pkg, "label" to label, "icon" to iconPng(info)))
        }
        return out
    }

    private fun iconPng(info: android.content.pm.ResolveInfo): ByteArray? = try {
        val drawable = info.loadIcon(packageManager)
        val size = (40 * resources.displayMetrics.density).toInt().coerceAtLeast(48)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bitmap.recycle()
        stream.toByteArray()
    } catch (e: Exception) {
        null
    }
}
