package com.stream.ledger.ui.settings

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.stream.ledger.core.designsystem.LocalStreamColors
import com.stream.ledger.core.designsystem.StreamIcons
import com.stream.ledger.core.designsystem.StreamShapes
import com.stream.ledger.ui.StreamViewModel
import kotlinx.coroutines.launch

@Composable
fun SettingsDialog(
    isVisible: Boolean,
    viewModel: StreamViewModel,
    onDismiss: () -> Unit
) {
    if (!isVisible) return

    val colors = LocalStreamColors.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var messageText by remember { mutableStateOf<String?>(null) }

    // SAF 导出 JSON 启动器
    val exportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json")
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                try {
                    val jsonStr = viewModel.repository.exportBackupJson()
                    val output = context.contentResolver.openOutputStream(uri)
                        ?: throw IllegalStateException("无法创建输出文件")
                    output.use { os -> os.write(jsonStr.toByteArray(Charsets.UTF_8)) }
                    messageText = "备份导出成功"
                } catch (e: Exception) {
                    messageText = "导出失败: ${e.message}"
                }
            }
        }
    }

    // SAF 恢复 JSON 启动器
    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                try {
                    val jsonStr = context.contentResolver.openInputStream(uri)?.use { ins ->
                        ins.bufferedReader(Charsets.UTF_8).readText()
                    } ?: throw IllegalStateException("无法读取备份文件")
                    val result = viewModel.repository.restoreBackupJson(jsonStr)
                    result.fold(
                        onSuccess = { count -> messageText = "成功恢复 $count 条账单" },
                        onFailure = { err -> messageText = "恢复失败: ${err.message}" }
                    )
                } catch (e: Exception) {
                    messageText = "读取文件失败: ${e.message}"
                }
            }
        }
    }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = StreamShapes.MainCard,
            colors = CardDefaults.cardColors(containerColor = colors.cardBackground),
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            Column(modifier = Modifier.padding(24.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "设置与数据",
                        style = MaterialTheme.typography.titleLarge,
                        color = colors.textPrimary
                    )
                    IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Close, contentDescription = "关闭", tint = colors.textSecondary)
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // 一键清除示例数据
                Surface(
                    shape = StreamShapes.SmallCard,
                    color = colors.paperBase,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            scope.launch {
                                try {
                                    val result = viewModel.clearSampleData()
                                    messageText = buildString {
                                        append("已清除 ${result.deletedTransactions} 条演示流水")
                                        if (result.removedAccounts > 0) {
                                            append("，移除 ${result.removedAccounts} 个示例账户")
                                        }
                                        if (result.keptAccounts > 0) {
                                            append("，保留 ${result.keptAccounts} 个仍被使用的示例账户")
                                        }
                                    }
                                } catch (e: Exception) {
                                    messageText = "清除失败: ${e.message ?: "未知错误"}"
                                }
                            }
                        }
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Delete, contentDescription = null, tint = colors.overBudgetRed)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "一键清除演示数据",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Medium,
                                color = colors.overBudgetRed
                            )
                            Text(
                                text = "清空内置 sample 流水，保留真实账目与默认分类",
                                style = MaterialTheme.typography.labelSmall,
                                color = colors.textSecondary
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // 导出 JSON 备份 (SAF)
                Surface(
                    shape = StreamShapes.SmallCard,
                    color = colors.paperBase,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            exportLauncher.launch("stream_backup_${System.currentTimeMillis() / 1000}.json")
                        }
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(StreamIcons.ExportFile, contentDescription = null, tint = colors.accentWarmYellow)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "导出 JSON 全量备份 (SAF)",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Medium,
                                color = colors.textPrimary
                            )
                            Text(
                                text = "排除示例数据，包含 schemaVersion 校验",
                                style = MaterialTheme.typography.labelSmall,
                                color = colors.textSecondary
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // 导入 JSON 备份 (SAF)
                Surface(
                    shape = StreamShapes.SmallCard,
                    color = colors.paperBase,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            importLauncher.launch(arrayOf("application/json"))
                        }
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(StreamIcons.ImportFile, contentDescription = null, tint = Color(0xFF1677FF))
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "恢复 JSON 备份 (SAF)",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Medium,
                                color = colors.textPrimary
                            )
                            Text(
                                text = "在事务中原子写入并校验版本",
                                style = MaterialTheme.typography.labelSmall,
                                color = colors.textSecondary
                            )
                        }
                    }
                }

                if (messageText != null) {
                    Spacer(modifier = Modifier.height(14.dp))
                    Text(
                        text = messageText!!,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.accentWarmYellow,
                        fontWeight = FontWeight.Medium
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))
                Divider(color = colors.hairline, thickness = 0.5.dp)
                Spacer(modifier = Modifier.height(12.dp))

                // 隐私提示
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(StreamIcons.Shield, contentDescription = null, tint = colors.incomeGreen, modifier = Modifier.size(14.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "无 INTERNET 权限 · 纯本地私密存储",
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary
                    )
                }
            }
        }
    }
}
