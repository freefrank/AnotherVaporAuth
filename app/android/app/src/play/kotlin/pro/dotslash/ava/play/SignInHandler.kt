package pro.dotslash.ava.play

import android.app.Activity
import android.os.Handler
import android.os.Looper
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import java.util.concurrent.Executor

/**
 * Google sign-in via Credential Manager: `signin.idToken` → id_token String.
 *
 * setFilterByAuthorizedAccounts(false) so first-time users see the full
 * account picker instead of an instant NoCredentialException.
 */
class SignInHandler {
    private val mainExecutor: Executor = Handler(Looper.getMainLooper()).let { h ->
        Executor { command -> h.post(command) }
    }

    fun idToken(activity: Activity, serverClientId: String?, result: GuardedResult) {
        if (serverClientId.isNullOrBlank()) {
            result.error("not_configured", "serverClientId is empty")
            return
        }
        val option = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(serverClientId)
            .build()
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(option)
            .build()
        CredentialManager.create(activity).getCredentialAsync(
            activity,
            request,
            null, // no cancellation signal
            mainExecutor,
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(response: GetCredentialResponse) {
                    val cred = response.credential
                    if (cred is CustomCredential &&
                        cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                    ) {
                        result.success(GoogleIdTokenCredential.createFrom(cred.data).idToken)
                    } else {
                        result.error("no_credential", "unexpected credential type: ${cred.type}")
                    }
                }

                override fun onError(e: GetCredentialException) {
                    when (e) {
                        is GetCredentialCancellationException ->
                            result.error("canceled", e.message)
                        is NoCredentialException ->
                            result.error("no_credential", e.message)
                        else ->
                            result.error("signin_failed", "${e.type}: ${e.message}")
                    }
                }
            },
        )
    }
}
