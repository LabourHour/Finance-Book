package com.stream.ledger.core.util

import kotlin.math.roundToLong

/**
 * 安全金额表达式解析器（禁止 eval / 反射）
 * 全程按「分」(Long) 整数运算，彻底避免浮点数漂移。
 */
object ArithmeticParser {
    const val MAX_AMOUNT_CENTS = 999_999_999L // 单笔上限：999.9999 万元

    /**
     * 将单个数符串（如 "12.5", "0.08", "100"）精确转换为分 (Long)
     */
    fun parseNumberToCents(raw: String): Long {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return 0L

        val isNegative = trimmed.startsWith("-")
        val clean = if (isNegative) trimmed.substring(1) else trimmed

        val parts = clean.split(".")
        val intPart = parts.getOrNull(0)?.toLongOrNull() ?: 0L

        var centsPart = 0L
        if (parts.size > 1) {
            val decStr = parts[1]
            centsPart = when {
                decStr.isEmpty() -> 0L
                decStr.length == 1 -> (decStr[0].digitToIntOrNull() ?: 0) * 10L
                decStr.length == 2 -> decStr.take(2).toLongOrNull() ?: 0L
                else -> {
                    // 超过两位小数进行四舍五入
                    val firstTwo = decStr.take(2).toDoubleOrNull() ?: 0.0
                    val thirdDigit = decStr.getOrNull(2)?.digitToIntOrNull() ?: 0
                    if (thirdDigit >= 5) (firstTwo + 1).toLong() else firstTwo.toLong()
                }
            }
        }

        val total = intPart * 100L + centsPart
        return if (isNegative) -total else total
    }

    /**
     * 解析算术表达式（支持加减、负号、未完成末尾操作符、多小数点等边界）
     * 例: "30+8" -> 3800L, "0.1+0.2" -> 30L, "100-25.5" -> 7450L
     */
    fun evaluate(expression: String): Long {
        val cleaned = expression.replace("\\s".toRegex(), "")
        if (cleaned.isEmpty()) return 0L

        val tokens = mutableListOf<String>()
        var currentNumber = StringBuilder()

        var i = 0
        while (i < cleaned.length) {
            val c = cleaned[i]
            if (c == '+' || c == '-') {
                // 处理开头负号或连续操作符
                if (currentNumber.isEmpty() && (tokens.isEmpty() || tokens.last() == "+" || tokens.last() == "-")) {
                    currentNumber.append(c)
                } else {
                    if (currentNumber.isNotEmpty()) {
                        tokens.add(currentNumber.toString())
                        currentNumber = StringBuilder()
                    }
                    tokens.add(c.toString())
                }
            } else if (c.isDigit()) {
                currentNumber.append(c)
            } else if (c == '.') {
                // 多小数点边界：只保留当前数字块中的第一个小数点
                if (!currentNumber.contains('.')) {
                    currentNumber.append(c)
                }
            }
            i++
        }

        if (currentNumber.isNotEmpty()) {
            tokens.add(currentNumber.toString())
        }

        if (tokens.isEmpty()) return 0L

        // 处理末尾多余操作符（如用户输入 "12+" 后直接点击完成）
        if (tokens.last() == "+" || tokens.last() == "-") {
            tokens.removeAt(tokens.size - 1)
        }

        if (tokens.isEmpty()) return 0L

        // 按分进行纯整数累加/累减
        var totalCents = 0L
        var currentOp = "+"

        for (token in tokens) {
            if (token == "+" || token == "-") {
                currentOp = token
            } else {
                val numCents = parseNumberToCents(token)
                if (currentOp == "+") {
                    totalCents += numCents
                } else {
                    totalCents -= numCents
                }
            }
        }

        // 金额上限与非负约束兜底
        val bounded = totalCents.coerceIn(0L, MAX_AMOUNT_CENTS)
        return bounded
    }

    /**
     * 将分为单位的金额转换为易读字符串 (用于输入回填)
     */
    fun centsToDisplayInput(cents: Long): String {
        if (cents == 0L) return ""
        val yuan = cents / 100
        val fen = cents % 100
        return if (fen == 0L) {
            yuan.toString()
        } else if (fen % 10L == 0L) {
            "$yuan.${fen / 10}"
        } else {
            "$yuan.${fen.toString().padStart(2, '0')}"
        }
    }
}
