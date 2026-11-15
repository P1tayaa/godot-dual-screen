package dev.p1tayaa.dualscreen

import android.app.Activity
import android.hardware.display.DisplayManager
import android.util.Log
import android.view.Display
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Godot singleton "DualScreenAndroid": shows one Godot screen on the device's second display.
 *
 * Two transports (pick by benchmark on the device):
 *  READBACK: Godot reads the viewport image, sends RGBA bytes with pushFrame(), shown in an ImageView.
 *  GL:       Godot passes its viewport GL texture id; each frame the render thread draws it on a
 *            SurfaceView on the second display, sharing Godot's EGL context (no copy).
 *
 * Touch on the second display comes back as the "second_touch" signal, in screen (base size) pixels.
 * Methods are called from Godot's main thread, which is the GL render thread on Android.
 */
class DualScreenPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        const val TRANSPORT_READBACK: Int = 0
        const val TRANSPORT_GL: Int = 1
        const val TOUCH_DOWN: Int = 0
        const val TOUCH_UP: Int = 1
        const val TOUCH_MOVE: Int = 2
        private const val TAG: String = "DualScreen"
    }

    private var presentation: SecondScreenPresentation? = null
    private val blitter: GlBlitter = GlBlitter()

    @Volatile private var textureId: Int = 0
    @Volatile private var flipY: Boolean = true
    @Volatile private var continuous: Boolean = true
    @Volatile private var pendingDraws: Int = 0

    override fun getPluginName(): String = "DualScreenAndroid"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        // action (TOUCH_*), pointer index, x, y in base pixels
        SignalInfo("second_touch", Integer::class.java, Integer::class.java, java.lang.Float::class.java, java.lang.Float::class.java),
    )

    /** Id of the first display that is not the one Godot runs on, or -1. */
    @UsedByGodot
    fun secondDisplayId(): Int = findSecondDisplay()?.displayId ?: -1

    /** Opens (or reopens) the second screen at `width` x `height` base pixels with a TRANSPORT_* mode. */
    @UsedByGodot
    fun open(width: Int, height: Int, transport: Int) {
        val activity: Activity = activity ?: return
        val display: Display = findSecondDisplay() ?: return Unit.also { Log.w(TAG, "no second display") }
        runOnUiThread {
            presentation?.dismiss()
            val p: SecondScreenPresentation = SecondScreenPresentation(
                activity, display, transport, width, height,
                onTouch = { action: Int, index: Int, x: Float, y: Float ->
                    runOnRenderThread { emitSignal("second_touch", action, index, x, y) }
                },
                onSurfaceGone = { runOnRenderThread { blitter.releaseSurface() } },
            )
            p.show()
            presentation = p
            Log.i(TAG, "opened on display ${display.displayId} transport=$transport ${width}x$height")
        }
    }

    @UsedByGodot
    fun close() {
        runOnUiThread {
            presentation?.dismiss()
            presentation = null
        }
    }

    /** READBACK: one RGBA8 frame, width * height * 4 bytes. */
    @UsedByGodot
    fun pushFrame(rgba: ByteArray) {
        presentation?.pushFrame(rgba)
    }

    /** GL: Godot's native texture id for the screen to show. 0 stops drawing. */
    @UsedByGodot
    fun setTexture(id: Int, flip: Boolean) {
        textureId = id
        flipY = flip
    }

    /** GL: true draws every Godot frame (an ALWAYS screen), false draws only after requestDraw() (ON_CHANGE). */
    @UsedByGodot
    fun setContinuous(on: Boolean) {
        continuous = on
        pendingDraws = 2
    }

    /** GL: draw the texture on the next frames (the screen changed). Two frames to cover a late buffer. */
    @UsedByGodot
    fun requestDraw() {
        pendingDraws = 2
    }

    /** Frames that actually reached the second display since open (both transports). */
    @UsedByGodot
    fun framesShown(): Int = presentation?.framesShown ?: 0

    override fun onGLSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        blitter.captureContext()
    }

    override fun onGLDrawFrame(gl: GL10?) {
        val p: SecondScreenPresentation = presentation ?: return
        if (p.transport != TRANSPORT_GL || textureId == 0) return
        if (!continuous && pendingDraws <= 0) return
        val target = p.glTarget() ?: return
        if (blitter.draw(target, textureId, flipY)) {
            p.framesShown += 1
            if (!continuous) pendingDraws -= 1
        }
    }

    override fun onMainDestroy() {
        presentation?.dismiss()
        presentation = null
    }

    private fun findSecondDisplay(): Display? {
        val activity: Activity = activity ?: return null
        val dm: DisplayManager = activity.getSystemService(DisplayManager::class.java)
        val ownId: Int = activity.display?.displayId ?: Display.DEFAULT_DISPLAY
        return dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull { d: Display -> d.displayId != ownId }
            ?: dm.displays.firstOrNull { d: Display -> d.displayId != ownId }
    }
}
