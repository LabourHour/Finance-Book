package com.stream.ledger

import com.stream.ledger.core.util.ArithmeticParser
import org.junit.Assert.assertEquals
import org.junit.Test

class ArithmeticParserTest {

    @Test
    fun testFloatingPointPrecision_PointOnePlusPointTwo() {
        // 关键用例：经典浮点数陷阱 0.1 + 0.2 必须严格等于 0.30 元 (30分)
        val result = ArithmeticParser.evaluate("0.1+0.2")
        assertEquals(30L, result)
    }

    @Test
    fun testBasicAdditionAndSubtraction() {
        assertEquals(3800L, ArithmeticParser.evaluate("30+8"))
        assertEquals(7450L, ArithmeticParser.evaluate("100-25.5"))
        assertEquals(1500L, ArithmeticParser.evaluate("10 + 5"))
    }

    @Test
    fun testTrailingOperatorHandling() {
        // 用户输入 12+ 之后直接点击完成，应自动计算有效前缀 12
        assertEquals(1200L, ArithmeticParser.evaluate("12+"))
        assertEquals(2550L, ArithmeticParser.evaluate("25.5-"))
    }

    @Test
    fun testMultipleDecimalPoints() {
        // 误输入多个小数点如 12.3.4，安全保留第一个有效小数
        assertEquals(1234L, ArithmeticParser.evaluate("12.3.4"))
    }

    @Test
    fun testRoundingBeyondTwoDecimals() {
        // 超过两位小数，四舍五入
        assertEquals(13L, ArithmeticParser.evaluate("0.125")) // 四舍五入到 0.13
        assertEquals(12L, ArithmeticParser.evaluate("0.124")) // 舍去到 0.12
    }

    @Test
    fun testLeadingNegativeAndBounds() {
        // 混合负数加法
        assertEquals(1000L, ArithmeticParser.evaluate("-10+20"))
        // 纯负数输入兜底为 0 分（单笔账单金额非负）
        assertEquals(0L, ArithmeticParser.evaluate("-50"))
    }

    @Test
    fun testCeilingCap() {
        // 超大金额上限兜底，防止溢出
        val huge = ArithmeticParser.evaluate("999999999999999")
        assertEquals(ArithmeticParser.MAX_AMOUNT_CENTS, huge)
    }
}
