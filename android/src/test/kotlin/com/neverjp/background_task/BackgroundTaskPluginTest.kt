package com.neverjp.background_task

import com.google.android.gms.location.Priority
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import org.mockito.Mockito

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class BackgroundTaskPluginTest {
  @Test
  fun onMethodCall_unknownMethod_returnsNotImplemented() {
    val plugin = BackgroundTaskPlugin()

    val call = MethodCall("unknown", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).notImplemented()
  }

  @Test
  fun priorityNoPower_usesPassiveLocationPriority() {
    val desiredAccuracy =
      LocationUpdatesService.DesiredAccuracy.lookup("priorityNoPower")

    assertEquals(
      Priority.PRIORITY_PASSIVE,
      desiredAccuracy.getLocationPriority(),
    )
  }
}
