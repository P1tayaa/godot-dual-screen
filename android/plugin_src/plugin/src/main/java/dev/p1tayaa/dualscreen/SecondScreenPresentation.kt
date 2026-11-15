package dev.p1tayaa.dualscreen

import android.app.Activity
import android.app.Presentation
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Bundle
import android.view.Display
import android.view.MotionEvent
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import java.nio.ByteBuffer

/** Where the screen lands in the view: integer scale, centred (letterbox). Same rule as Godot's integer stretch. */
class ScreenFit(viewW: Int, viewH: Int, val baseW: Int, val baseH: Int) {
    val scale: Int = maxOf(1, minOf(viewW / baseW, viewH / baseH))
    val left: Int = (viewW - baseW * scale) / 2
    val top: Int = (viewH - baseH * scale) / 2
    val rect: Rect = Rect(left, top, left + baseW * scale, top + baseH * scale)
}

/** What the GL blitter needs, read on the render thread. */
class GlTarget(val surface: Surface, val fit: ScreenFit, val viewW: Int, val viewH: Int)

/**
 * The second display. Not focusable, so the gamepad and keys stay with Godot.
 * READBACK shows a Bitmap drawn with nearest scaling, GL exposes a SurfaceView for the blitter.
 */
class SecondScreenPresentation(
    activity: Activity,
    display: Display,
    val transport: Int,
    private val baseW: Int,
    private val baseH: Int,
    private val onTouch: (Int, Int, Float, Float) -> Unit,
    private val onSurfaceGone: () -> Unit,
) : Presentation(activity, display) {

    @Volatile var framesShown: Int = 0
    @Volatile private var target: GlTarget? = null

    private val bitmap: Bitmap = Bitmap.createBitmap(baseW, baseH, Bitmap.Config.ARGB_8888)
    private val bitmapLock: Any = Any()
    private var bitmapView: BitmapView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window?.addFlags(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val view: View = if (transport == DualScreenPlugin.TRANSPORT_GL) makeSurfaceView() else makeBitmapView()
        view.setOnTouchListener { v: View, e: MotionEvent -> handleTouch(v, e); true }
        setContentView(view)
    }

    /** Godot main thread. Bitmap ARGB_8888 memory is RGBA byte order, same as Godot's FORMAT_RGBA8. */
    fun pushFrame(rgba: ByteArray) {
        if (rgba.size != baseW * baseH * 4) return
        synchronized(bitmapLock) { bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba)) }
        bitmapView?.postInvalidate()
    }

    fun glTarget(): GlTarget? = target

    private fun makeBitmapView(): View {
        val v: BitmapView = BitmapView(this)
        bitmapView = v
        return v
    }

    private fun makeSurfaceView(): View {
        val v: SurfaceView = SurfaceView(context)
        v.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {}

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                target = GlTarget(holder.surface, ScreenFit(width, height, baseW, baseH), width, height)
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                target = null
                // HACK: the EGL surface is released on the render thread without waiting for it. Fine for the
                // bench (the screen only closes on exit or transport change); blitter.draw() also drops dead surfaces.
                onSurfaceGone()
            }
        })
        return v
    }

    private fun handleTouch(v: View, e: MotionEvent) {
        val fit: ScreenFit = ScreenFit(v.width, v.height, baseW, baseH)
        fun emit(action: Int, i: Int) {
            val x: Float = (e.getX(i) - fit.left) / fit.scale
            val y: Float = (e.getY(i) - fit.top) / fit.scale
            onTouch(action, e.getPointerId(i), x, y)
        }
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> emit(DualScreenPlugin.TOUCH_DOWN, e.actionIndex)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL ->
                emit(DualScreenPlugin.TOUCH_UP, e.actionIndex)
            MotionEvent.ACTION_MOVE -> for (i: Int in 0 until e.pointerCount) emit(DualScreenPlugin.TOUCH_MOVE, i)
        }
    }

    /** Draws the bitmap at integer scale without filtering. */
    private class BitmapView(private val owner: SecondScreenPresentation) : View(owner.context) {
        private val paint: Paint = Paint().apply { isFilterBitmap = false; isAntiAlias = false }

        override fun onDraw(canvas: Canvas) {
            canvas.drawColor(Color.BLACK)
            val fit: ScreenFit = ScreenFit(width, height, owner.baseW, owner.baseH)
            synchronized(owner.bitmapLock) { canvas.drawBitmap(owner.bitmap, null, fit.rect, paint) }
            owner.framesShown += 1
        }
    }
}
