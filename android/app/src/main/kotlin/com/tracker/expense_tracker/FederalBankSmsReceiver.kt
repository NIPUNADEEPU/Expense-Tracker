package com.tracker.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.text.SimpleDateFormat
import java.util.Locale

/** Imports only new Federal Bank UPI debit confirmations. Message text is not retained. */
class FederalBankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!context.getSharedPreferences("sms_import", Context.MODE_PRIVATE)
                .getBoolean("enabled", false)) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return
        val sender = messages.firstOrNull()?.originatingAddress.orEmpty()
        if (!sender.contains("FEDBNK", ignoreCase = true)) return
        val body = messages.joinToString(separator = "") { it.messageBody.orEmpty() }
        val parsed = parse(body) ?: return
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val pending = goAsync()
        val reference = FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection("transactions").document("federal_sms_${parsed.reference}")

        reference.get()
            .addOnSuccessListener { document ->
                if (document.exists()) {
                    pending.finish()
                } else {
                    reference.set(
                        mapOf(
                            "id" to reference.id,
                            "title" to parsed.payee,
                            "amount" to parsed.amount,
                            "type" to "expense",
                            "category" to "uncategorized",
                            "date" to parsed.date,
                            "source" to "federal_bank_sms"
                        )
                    ).addOnFailureListener { error ->
                        Log.w(TAG, "Could not save parsed Federal Bank transaction", error)
                    }.addOnCompleteListener { pending.finish() }
                }
            }
            .addOnFailureListener { error ->
                Log.w(TAG, "Could not check for duplicate SMS transaction", error)
                pending.finish()
            }
    }

    private data class ParsedDebit(
        val amount: Double,
        val payee: String,
        val reference: String,
        val date: String
    )

    private fun parse(body: String): ParsedDebit? {
        if (!body.contains("via UPI", ignoreCase = true) ||
            !body.contains("Debited", ignoreCase = true)) return null

        val amount = Regex(
            "Debited\\s+Rs\\.?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
            RegexOption.IGNORE_CASE
        ).find(body)?.groupValues?.get(1)?.replace(",", "")?.toDoubleOrNull() ?: return null

        val dateMatch = Regex(
            "\\bon\\s+(\\d{1,2}[A-Za-z]{3}\\d{2})\\s+(\\d{1,2}:\\d{2})",
            RegexOption.IGNORE_CASE
        ).find(body) ?: return null
        val dateParser = SimpleDateFormat("ddMMMyy HH:mm", Locale.ENGLISH).apply {
            isLenient = false
        }
        val parsedDate = runCatching {
            dateParser.parse("${dateMatch.groupValues[1]} ${dateMatch.groupValues[2]}")
        }.getOrNull() ?: return null

        val payeeAndRef = Regex(
            "via\\s+UPI\\s+to\\s+(.+?)\\s*(?:S\\.)?\\s*Ref(?:erence)?\\s*:?[ ]*(\\d{6,})",
            RegexOption.IGNORE_CASE
        ).find(body) ?: return null
        val payee = payeeAndRef.groupValues[1].trim().trimEnd('.', ' ')
        if (payee.isEmpty()) return null

        val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
            .format(parsedDate)
        return ParsedDebit(amount, payee, payeeAndRef.groupValues[2], isoDate)
    }

    companion object {
        private const val TAG = "FederalBankSms"
    }
}
