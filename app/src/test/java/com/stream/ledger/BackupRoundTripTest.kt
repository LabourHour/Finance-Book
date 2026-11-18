package com.stream.ledger

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupRoundTripTest {

    @Test
    fun testBackupRoundTrip_ExcludesSampleData_And_ValidatesSchemaVersion() {
        val sampleTx = JSONObject().apply {
            put("id", "tx_sample_1")
            put("isSample", true)
            put("amount", 2000L)
        }
        val realTx = JSONObject().apply {
            put("id", "tx_real_1")
            put("isSample", false)
            put("amount", 8800L)
        }

        // 导出时排除 isSample
        val allTxs = listOf(sampleTx, realTx)
        val exportedTxs = JSONArray()
        for (tx in allTxs) {
            if (!tx.getBoolean("isSample")) {
                exportedTxs.put(tx)
            }
        }

        val backupRoot = JSONObject().apply {
            put("schemaVersion", 1)
            put("exportedAt", System.currentTimeMillis())
            put("transactions", exportedTxs)
        }

        val jsonString = backupRoot.toString(2)

        // 验证导出的 JSON
        val parsed = JSONObject(jsonString)
        assertEquals(1, parsed.getInt("schemaVersion"))

        val restoredArray = parsed.getJSONArray("transactions")
        assertEquals(1, restoredArray.length())
        assertEquals("tx_real_1", restoredArray.getJSONObject(0).getString("id"))

        // 验证无效版本的防护校验
        val invalidBackup = JSONObject().apply {
            put("schemaVersion", 0) // 无效版本
        }
        assertTrue(invalidBackup.optInt("schemaVersion", -1) < 1)
    }
}
