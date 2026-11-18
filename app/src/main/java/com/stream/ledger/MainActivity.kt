package com.stream.ledger

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.stream.ledger.core.designsystem.StreamTheme
import com.stream.ledger.ui.StreamViewModel
import com.stream.ledger.ui.main.MainScreen

class MainActivity : ComponentActivity() {
    private val viewModel: StreamViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            StreamTheme {
                MainScreen(viewModel = viewModel)
            }
        }
    }
}
