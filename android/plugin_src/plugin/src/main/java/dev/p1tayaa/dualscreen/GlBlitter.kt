package dev.p1tayaa.dualscreen

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES30
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws one Godot texture on another window surface, on Godot's render thread, with Godot's own EGL context.
 * Saves and restores every GL state it touches, because Godot's renderer caches its state.
 */
class GlBlitter {

    companion object {
        private const val TAG: String = "DualScreen"

        private const val VERTEX: String = """#version 300 es
in vec2 a_pos;
uniform float u_flip;
out vec2 v_uv;
void main() {
    v_uv = a_pos * 0.5 + 0.5;
    if (u_flip > 0.5) v_uv.y = 1.0 - v_uv.y;
    gl_Position = vec4(a_pos, 0.0, 1.0);
}"""

        private const val FRAGMENT: String = """#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D u_tex;
out vec4 frag;
void main() { frag = vec4(texture(u_tex, v_uv).rgb, 1.0); }"""
    }

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var config: EGLConfig? = null
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var forSurface: Surface? = null

    private var program: Int = 0
    private var vbo: Int = 0
    private var vao: Int = 0
    private var flipLoc: Int = -1

    private val quad: FloatBuffer = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply {
        put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
        position(0)
    }
    private val tmp: IntArray = IntArray(4)

    /** Render thread, when Godot's GL surface is (re)created: remember its display, context and config. */
    fun captureContext() {
        display = EGL14.eglGetCurrentDisplay()
        context = EGL14.eglGetCurrentContext()
        val id: IntArray = IntArray(1)
        EGL14.eglQueryContext(display, context, EGL14.EGL_CONFIG_ID, id, 0)
        val configs: Array<EGLConfig?> = arrayOfNulls(1)
        val count: IntArray = IntArray(1)
        EGL14.eglChooseConfig(display, intArrayOf(EGL14.EGL_CONFIG_ID, id[0], EGL14.EGL_NONE), 0, configs, 0, 1, count, 0)
        config = configs[0]
        // New context: old GL objects are gone.
        program = 0
        eglSurface = EGL14.EGL_NO_SURFACE
        forSurface = null
        Log.i(TAG, "captured EGL context, config id ${id[0]}")
    }

    fun releaseSurface() {
        if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, eglSurface)
        eglSurface = EGL14.EGL_NO_SURFACE
        forSurface = null
    }

    /** Render thread, after Godot drew its frame. Returns true when a frame reached the second display. */
    fun draw(target: GlTarget, textureId: Int, flipY: Boolean): Boolean {
        if (context == EGL14.EGL_NO_CONTEXT || config == null) return false
        if (!target.surface.isValid) {
            releaseSurface()
            return false
        }
        if (forSurface !== target.surface) {
            releaseSurface()
            eglSurface = EGL14.eglCreateWindowSurface(display, config, target.surface, intArrayOf(EGL14.EGL_NONE), 0)
            if (eglSurface == EGL14.EGL_NO_SURFACE) {
                Log.e(TAG, "eglCreateWindowSurface failed: 0x${Integer.toHexString(EGL14.eglGetError())}")
                return false
            }
            forSurface = target.surface
        }

        val prevDraw: EGLSurface = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW)
        val prevRead: EGLSurface = EGL14.eglGetCurrentSurface(EGL14.EGL_READ)
        if (!EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)) return false
        val saved: SavedState = SavedState.capture(tmp)
        try {
            if (program == 0) setup()
            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
            GLES30.glDisable(GLES30.GL_SCISSOR_TEST)
            GLES30.glDisable(GLES30.GL_BLEND)
            GLES30.glDisable(GLES30.GL_DEPTH_TEST)
            GLES30.glDisable(GLES30.GL_CULL_FACE)
            GLES30.glDisable(GLES30.GL_STENCIL_TEST)
            GLES30.glColorMask(true, true, true, true)
            GLES30.glViewport(0, 0, target.viewW, target.viewH)
            GLES30.glClearColor(0f, 0f, 0f, 1f)
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
            // GL viewport origin is bottom-left.
            val r = target.fit.rect
            GLES30.glViewport(r.left, target.viewH - r.bottom, r.width(), r.height())

            GLES30.glUseProgram(program)
            GLES30.glUniform1f(flipLoc, if (flipY) 1f else 0f)
            GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
            GLES30.glBindSampler(0, 0)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
            GLES30.glGetTexParameteriv(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, tmp, 0)
            val minFilter: Int = tmp[0]
            GLES30.glGetTexParameteriv(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, tmp, 0)
            val magFilter: Int = tmp[0]
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_NEAREST)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_NEAREST)
            GLES30.glBindVertexArray(vao)
            GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, minFilter)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, magFilter)
            EGL14.eglSwapBuffers(display, eglSurface)
        } finally {
            saved.restore()
            EGL14.eglMakeCurrent(display, prevDraw, prevRead, context)
        }
        return true
    }

    private fun setup() {
        program = link(compile(GLES30.GL_VERTEX_SHADER, VERTEX), compile(GLES30.GL_FRAGMENT_SHADER, FRAGMENT))
        flipLoc = GLES30.glGetUniformLocation(program, "u_flip")
        GLES30.glUseProgram(program)
        GLES30.glUniform1i(GLES30.glGetUniformLocation(program, "u_tex"), 0)
        val ids: IntArray = IntArray(1)
        GLES30.glGenVertexArrays(1, ids, 0)
        vao = ids[0]
        GLES30.glGenBuffers(1, ids, 0)
        vbo = ids[0]
        GLES30.glBindVertexArray(vao)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo)
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, 8 * 4, quad, GLES30.GL_STATIC_DRAW)
        val posLoc: Int = GLES30.glGetAttribLocation(program, "a_pos")
        GLES30.glEnableVertexAttribArray(posLoc)
        GLES30.glVertexAttribPointer(posLoc, 2, GLES30.GL_FLOAT, false, 0, 0)
    }

    private fun compile(type: Int, src: String): Int {
        val s: Int = GLES30.glCreateShader(type)
        GLES30.glShaderSource(s, src)
        GLES30.glCompileShader(s)
        GLES30.glGetShaderiv(s, GLES30.GL_COMPILE_STATUS, tmp, 0)
        if (tmp[0] == 0) Log.e(TAG, "shader: ${GLES30.glGetShaderInfoLog(s)}")
        return s
    }

    private fun link(vs: Int, fs: Int): Int {
        val p: Int = GLES30.glCreateProgram()
        GLES30.glAttachShader(p, vs)
        GLES30.glAttachShader(p, fs)
        GLES30.glLinkProgram(p)
        GLES30.glGetProgramiv(p, GLES30.GL_LINK_STATUS, tmp, 0)
        if (tmp[0] == 0) Log.e(TAG, "link: ${GLES30.glGetProgramInfoLog(p)}")
        return p
    }

    /** GL state Godot may rely on between frames. */
    private class SavedState(
        val program: Int, val activeTexture: Int, val texture: Int, val sampler: Int, val vao: Int, val arrayBuffer: Int,
        val framebuffer: Int, val viewport: IntArray, val scissor: Boolean, val blend: Boolean, val depth: Boolean,
        val cull: Boolean, val stencil: Boolean,
    ) {
        companion object {
            fun capture(tmp: IntArray): SavedState {
                fun get(name: Int): Int { GLES30.glGetIntegerv(name, tmp, 0); return tmp[0] }
                val active: Int = get(GLES30.GL_ACTIVE_TEXTURE)
                GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
                val texture: Int = get(GLES30.GL_TEXTURE_BINDING_2D)
                val sampler: Int = get(GLES30.GL_SAMPLER_BINDING)
                val vp: IntArray = IntArray(4)
                GLES30.glGetIntegerv(GLES30.GL_VIEWPORT, vp, 0)
                return SavedState(
                    get(GLES30.GL_CURRENT_PROGRAM), active, texture, sampler, get(GLES30.GL_VERTEX_ARRAY_BINDING),
                    get(GLES30.GL_ARRAY_BUFFER_BINDING), get(GLES30.GL_FRAMEBUFFER_BINDING), vp,
                    GLES30.glIsEnabled(GLES30.GL_SCISSOR_TEST), GLES30.glIsEnabled(GLES30.GL_BLEND),
                    GLES30.glIsEnabled(GLES30.GL_DEPTH_TEST), GLES30.glIsEnabled(GLES30.GL_CULL_FACE),
                    GLES30.glIsEnabled(GLES30.GL_STENCIL_TEST),
                )
            }
        }

        fun restore() {
            fun set(cap: Int, on: Boolean) { if (on) GLES30.glEnable(cap) else GLES30.glDisable(cap) }
            GLES30.glUseProgram(program)
            GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, texture)
            GLES30.glBindSampler(0, sampler)
            GLES30.glActiveTexture(activeTexture)
            GLES30.glBindVertexArray(vao)
            GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, arrayBuffer)
            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffer)
            GLES30.glViewport(viewport[0], viewport[1], viewport[2], viewport[3])
            set(GLES30.GL_SCISSOR_TEST, scissor)
            set(GLES30.GL_BLEND, blend)
            set(GLES30.GL_DEPTH_TEST, depth)
            set(GLES30.GL_CULL_FACE, cull)
            set(GLES30.GL_STENCIL_TEST, stencil)
        }
    }
}
