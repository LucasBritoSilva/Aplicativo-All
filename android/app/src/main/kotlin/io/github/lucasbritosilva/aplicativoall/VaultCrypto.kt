package io.github.lucasbritosilva.aplicativoall

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Cifragem do cofre com uma chave AES-256 guardada no Android Keystore.
 *
 * A chave nunca sai do Keystore e só pode ser usada por [VALIDITY_SECONDS]
 * depois de o usuário se autenticar (biometria forte ou PIN/padrão/senha
 * do aparelho). Nada aqui grava texto aberto em disco nem em log.
 */
class VaultCrypto(private val context: Context) {

    companion object {
        private const val KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "aplicativo_all_vault_v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_SIZE = 12
        private const val TAG_BITS = 128

        /** Tempo em que a chave fica liberada após a autenticação. */
        const val VALIDITY_SECONDS = 600
    }

    /** Até quando o cofre fica destrancado nesta sessão (relógio monotônico). */
    private var unlockedUntil = 0L

    private val keyStore: KeyStore by lazy { KeyStore.getInstance(KEYSTORE).apply { load(null) } }

    fun isDeviceSecure(): Boolean {
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return km.isDeviceSecure
    }

    fun keyExists(): Boolean = try {
        keyStore.containsAlias(ALIAS)
    } catch (e: Exception) {
        false
    }

    fun isUnlocked(): Boolean = SystemClock.elapsedRealtime() < unlockedUntil

    fun state(): String = when {
        !isDeviceSecure() -> "no_lock_screen"
        !keyExists() -> "not_created"
        isUnlocked() -> "unlocked"
        else -> "locked"
    }

    /** Cria a chave (se ainda não existe). Exige bloqueio de tela. */
    fun ensureKey() {
        if (keyExists()) return
        val builder = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                VALIDITY_SECONDS,
                KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(VALIDITY_SECONDS)
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(builder.build())
        generator.generateKey()
    }

    private fun key(): SecretKey = keyStore.getKey(ALIAS, null) as SecretKey

    /**
     * Chamado depois de uma autenticação bem-sucedida. Confere se a chave
     * ainda vale e marca o cofre como destrancado.
     * Devolve "ok", "invalidated" ou "error".
     */
    fun afterAuthentication(): String = try {
        Cipher.getInstance(TRANSFORMATION).init(Cipher.ENCRYPT_MODE, key())
        unlockedUntil = SystemClock.elapsedRealtime() + (VALIDITY_SECONDS - 30) * 1000L
        "ok"
    } catch (e: KeyPermanentlyInvalidatedException) {
        lock()
        "invalidated"
    } catch (e: UserNotAuthenticatedException) {
        lock()
        "error"
    } catch (e: Exception) {
        lock()
        "error"
    }

    fun lock() {
        unlockedUntil = 0L
    }

    /** Apaga a chave; tudo o que foi cifrado com ela fica ilegível. */
    fun reset() {
        lock()
        try {
            if (keyExists()) keyStore.deleteEntry(ALIAS)
        } catch (e: Exception) {
            // Sem chave para apagar.
        }
    }

    /** Base64 de IV + texto cifrado + tag, ou nulo se o cofre está trancado. */
    fun encrypt(plain: String): String? {
        if (!isUnlocked()) return null
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key())
            val iv = cipher.iv
            val body = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
            Base64.encodeToString(iv + body, Base64.NO_WRAP)
        } catch (e: UserNotAuthenticatedException) {
            lock()
            null
        } catch (e: Exception) {
            null
        }
    }

    /** Decifra; nulo para itens ilegíveis ou com o cofre trancado. */
    fun decrypt(payload: String): String? {
        if (!isUnlocked()) return null
        return try {
            val bytes = Base64.decode(payload, Base64.NO_WRAP)
            if (bytes.size <= IV_SIZE) return null
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                key(),
                GCMParameterSpec(TAG_BITS, bytes, 0, IV_SIZE),
            )
            String(cipher.doFinal(bytes, IV_SIZE, bytes.size - IV_SIZE), Charsets.UTF_8)
        } catch (e: UserNotAuthenticatedException) {
            lock()
            null
        } catch (e: Exception) {
            null
        }
    }
}
