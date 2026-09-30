package com.gemdrake.gemdrake_isles

import android.media.AudioManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Volume buttons adjust media (game) volume while the game is open,
        // even between sounds, instead of the ringer/notification volume.
        volumeControlStream = AudioManager.STREAM_MUSIC
    }
}
