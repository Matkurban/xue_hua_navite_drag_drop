package com.kurban.xue_hua_navite_drag_drop

import androidx.core.content.FileProvider

/**
 * Dedicated [FileProvider] subclass for `xue_hua_navite_drag_drop` so that the plugin
 * does not collide with the host app's own `androidx.core.content.FileProvider`.
 */
class DragDropFileProvider : FileProvider()
