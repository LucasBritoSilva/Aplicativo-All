package io.github.lucasbritosilva.aplicativoall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONObject

/**
 * Serviço que mostra, sobre o app monitorado em uso, o tempo que ainda
 * resta do limite diário. Não bloqueia nem fecha nenhum app.
 *
 * Economia de bateria: com a tela desligada nada é verificado; com a tela
 * ligada, os eventos de uso são lidos uma vez por segundo, só do intervalo
 * desde a última leitura.
 */
class UsageMonitorService : Service() {

    companion object {
        private const val PREFS = "aplicativo_all_monitor"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_LIMITS = "limits"
        private const val CHANNEL = "monitor_uso"
        private const val NOTIFICATION_ID = 900000100

        @Volatile
        var running = false
            private set

        fun saveConfig(context: Context, enabled: Boolean, limits: Map<String, Int>) {
            val json = JSONObject()
            for ((pkg, minutes) in limits) json.put(pkg, minutes)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_ENABLED, enabled)
                .putString(KEY_LIMITS, json.toString())
                .apply()
        }

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

        fun loadLimits(context: Context): Map<String, Int> {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_LIMITS, null) ?: return emptyMap()
            return try {
                val json = JSONObject(raw)
                buildMap { json.keys().forEach { put(it, json.getInt(it)) } }
            } catch (e: Exception) {
                emptyMap()
            }
        }

        /** Liga o serviço (ou atualiza os limites dele). Falso se o Android recusar. */
        fun start(context: Context): Boolean = try {
            val intent = Intent(context, UsageMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (e: Exception) {
            false
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, UsageMonitorService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var limits: Map<String, Int> = emptyMap()
    private var overlay: TextView? = null
    private var screenOn = true

    private var tracker: UsageStatsHelper.Tracker? = null
    private var trackerDayStart = 0L
    private var lastQuery = 0L

    /** App monitorado em uso, uso de hoje até [enteredAt] e o instante. */
    private var monitoredPkg: String? = null
    private var baseUsage = 0L
    private var enteredAt = 0L

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    screenOn = false
                    handler.removeCallbacks(tick)
                    hideOverlay()
                }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                    if (!screenOn) {
                        screenOn = true
                        handler.removeCallbacks(tick)
                        handler.post(tick)
                    }
                }
            }
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            try {
                update()
            } catch (e: Exception) {
                hideOverlay()
            }
            if (screenOn) handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        screenOn = pm.isInteractive
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        running = true
        limits = loadLimits(this)
        resetTracking()
        handler.removeCallbacks(tick)
        if (screenOn) handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(tick)
        hideOverlay()
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            // Já removido.
        }
        super.onDestroy()
    }

    private fun startInForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Contador de uso de apps", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Indica que o contador flutuante do limite de apps está ligado"
                    setShowBadge(false)
                },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Limite de uso de apps")
            .setContentText("Contador flutuante ligado. Toque para abrir o All.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun resetTracking() {
        tracker = null
        monitoredPkg = null
    }

    private fun update() {
        if (!UsageStatsHelper.hasAccess(this) || limits.isEmpty()) {
            hideOverlay()
            return
        }
        val now = System.currentTimeMillis()
        val dayStart = UsageStatsHelper.startOfToday(now)

        // Virou o dia (ou primeira leitura): recomeça a contagem.
        var t = tracker
        if (t == null || dayStart != trackerDayStart || now < lastQuery) {
            t = UsageStatsHelper.track(this, dayStart, now)
            tracker = t
            trackerDayStart = dayStart
            monitoredPkg = null
        } else {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
            val events = usm.queryEvents(lastQuery, now)
            if (events != null) {
                val e = android.app.usage.UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(e)
                    t.onEvent(e.eventType, e.packageName, e.timeStamp)
                }
            }
        }
        lastQuery = now

        val current = t.current
        val limit = current?.let { limits[it] }
        if (current == null || limit == null || current == packageName) {
            monitoredPkg = null
            hideOverlay()
            return
        }
        if (current != monitoredPkg) {
            monitoredPkg = current
            baseUsage = t.totalsUntil(now)[current] ?: 0L
            enteredAt = now
        }
        val used = baseUsage + (now - enteredAt)
        val remaining = limit * 60_000L - used
        showOverlay(remaining)
    }

    private fun format(ms: Long): String {
        val total = ms / 1000
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) String.format("%d:%02d:%02d", h, m, s) else String.format("%02d:%02d", m, s)
    }

    private fun showOverlay(remaining: Long) {
        if (!canDraw()) return
        val view = overlay ?: createOverlay() ?: return
        val exceeded = remaining <= 0
        view.text = if (exceeded) "Limite atingido +${format(-remaining)}" else "Restam ${format(remaining)}"
        (view.background as? GradientDrawable)?.setStroke(
            dp(1.5f),
            if (exceeded) Color.parseColor("#F07A74") else Color.parseColor("#9D7BFF"),
        )
    }

    private fun canDraw(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun dp(v: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics).toInt()

    private fun createOverlay(): TextView? {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(dp(12f), dp(6f), dp(12f), dp(6f))
            background = GradientDrawable().apply {
                cornerRadius = dp(18f).toFloat()
                setColor(Color.parseColor("#E615151A"))
            }
        }
        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(12f)
            y = dp(56f)
        }
        return try {
            wm.addView(view, params)
            overlay = view
            view
        } catch (e: Exception) {
            null
        }
    }

    private fun hideOverlay() {
        val view = overlay ?: return
        overlay = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view)
        } catch (e: Exception) {
            // Já removida.
        }
    }
}
