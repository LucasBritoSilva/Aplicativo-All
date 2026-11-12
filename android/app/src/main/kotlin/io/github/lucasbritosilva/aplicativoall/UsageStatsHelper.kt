package io.github.lucasbritosilva.aplicativoall

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import java.util.Calendar

/**
 * Leitura do tempo de uso de cada app a partir dos eventos do Android
 * (UsageStatsManager). Precisa da permissão "Acesso ao uso".
 */
object UsageStatsHelper {

    // Tipos de evento (os números são os da API do Android).
    private const val RESUMED = 1 // ACTIVITY_RESUMED / MOVE_TO_FOREGROUND
    private const val PAUSED = 2 // ACTIVITY_PAUSED / MOVE_TO_BACKGROUND
    private const val SCREEN_OFF = 16 // SCREEN_NON_INTERACTIVE
    private const val KEYGUARD_SHOWN = 17
    private const val STOPPED = 23 // ACTIVITY_STOPPED
    private const val SHUTDOWN = 26 // DEVICE_SHUTDOWN

    fun hasAccess(context: Context): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Meia-noite de hoje no fuso do aparelho, em milissegundos. */
    fun startOfToday(now: Long = System.currentTimeMillis()): Long =
        Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    /** Estado da contagem enquanto percorre os eventos. */
    class Tracker(private val from: Long) {
        val totals = HashMap<String, Long>()
        var current: String? = null
            private set
        private var since = 0L

        private fun close(at: Long) {
            val pkg = current ?: return
            val start = maxOf(since, from)
            if (at > start) totals[pkg] = (totals[pkg] ?: 0L) + (at - start)
            current = null
        }

        fun onEvent(type: Int, pkg: String?, time: Long) {
            when (type) {
                RESUMED -> {
                    if (pkg == null) return
                    if (current != pkg) {
                        close(time)
                        current = pkg
                        since = time
                    }
                }
                PAUSED, STOPPED -> if (pkg != null && pkg == current) close(time)
                SCREEN_OFF, KEYGUARD_SHOWN, SHUTDOWN -> close(time)
            }
        }

        /** Fecha o app em uso no instante [end] sem perder quem é ele. */
        fun totalsUntil(end: Long): Map<String, Long> {
            val out = HashMap(totals)
            val pkg = current
            if (pkg != null) {
                val start = maxOf(since, from)
                if (end > start) out[pkg] = (out[pkg] ?: 0L) + (end - start)
            }
            return out
        }
    }

    /**
     * Percorre os eventos de [queryFrom] até [end] e devolve o tracker.
     * Começa algumas horas antes de [countFrom] para saber qual app já
     * estava aberto à meia-noite, mas só conta a partir de [countFrom].
     */
    fun track(context: Context, countFrom: Long, end: Long, queryFrom: Long = countFrom - 3 * 3600_000L): Tracker {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val tracker = Tracker(countFrom)
        val events = usm.queryEvents(queryFrom, end) ?: return tracker
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            tracker.onEvent(event.eventType, event.packageName, event.timeStamp)
        }
        return tracker
    }

    /** Tempo de uso de hoje por pacote, em milissegundos. */
    fun usageToday(context: Context): Map<String, Long> {
        if (!hasAccess(context)) return emptyMap()
        val now = System.currentTimeMillis()
        return track(context, startOfToday(now), now).totalsUntil(now)
    }
}
