package io.github.lucasbritosilva.aplicativoall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Religa o contador de uso de apps depois que o celular reinicia, se o
 * usuário o deixou ligado. Se o Android não permitir (algumas versões
 * restringem serviços iniciados no boot), ele volta ao abrir o app.
 */
class MonitorBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        if (!UsageMonitorService.isEnabled(context)) return
        if (!UsageStatsHelper.hasAccess(context)) return
        UsageMonitorService.start(context)
    }
}
