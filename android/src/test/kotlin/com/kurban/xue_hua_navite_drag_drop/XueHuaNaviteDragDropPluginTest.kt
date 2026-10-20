package com.kurban.xue_hua_navite_drag_drop

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class XueHuaNaviteDragDropPluginTest {
    @Test
    fun onMethodCall_setDropEffect_returnsSuccess() {
        val plugin = XueHuaNaviteDragDropPlugin()

        val call = MethodCall("setDropEffect", mapOf("operation" to "copy"))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(null)
    }
}
