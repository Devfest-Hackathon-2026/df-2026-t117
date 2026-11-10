package jp.tasuku.ar_guide.ar

import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.FloatBuffer
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Flat turn arrow lying on the floor, in the anchor's local frame:
 * x = right, z = towards the user (forward is -z), y = up (floor normal).
 *
 * Same look as the mock's S11 arrow (_arScene.tsx): a thick yellow arrow with a dark outline. A brighter
 * band runs along it from tail to head so the direction reads even when the arrow is partly off-screen.
 */
class ArrowRenderer {
    private var program = 0
    private var positionAttr = 0
    private var progressAttr = 0
    private var mvpUniform = 0
    private var colorUniform = 0
    private var timeUniform = 0
    private var flowUniform = 0

    private var outline: FloatBuffer? = null
    private var outlineCount = 0
    private var fill: FloatBuffer? = null
    private var fillCount = 0
    private var turn: Turn? = null

    private val modelView = FloatArray(16)
    private val mvp = FloatArray(16)

    fun createOnGlThread() {
        program = GlUtil.program(VERTEX_SHADER, FRAGMENT_SHADER)
        positionAttr = GLES20.glGetAttribLocation(program, "a_Position")
        progressAttr = GLES20.glGetAttribLocation(program, "a_Progress")
        mvpUniform = GLES20.glGetUniformLocation(program, "u_Mvp")
        colorUniform = GLES20.glGetUniformLocation(program, "u_Color")
        timeUniform = GLES20.glGetUniformLocation(program, "u_Time")
        flowUniform = GLES20.glGetUniformLocation(program, "u_Flow")
        turn?.let { build(it) }
    }

    fun setTurn(value: Turn) {
        if (value == turn && fill != null) return
        turn = value
        build(value)
    }

    private fun build(value: Turn) {
        val path = ArrowMesh.path(value)
        val o = ArrowMesh.build(path, HALF_WIDTH + OUTLINE, HEAD_HALF_WIDTH + OUTLINE * 1.6f, HEAD_LENGTH + OUTLINE * 2.2f, OUTLINE)
        val f = ArrowMesh.build(path, HALF_WIDTH, HEAD_HALF_WIDTH, HEAD_LENGTH, 0f)
        outline = GlUtil.floatBuffer(o)
        outlineCount = o.size / ArrowMesh.STRIDE
        fill = GlUtil.floatBuffer(f)
        fillCount = f.size / ArrowMesh.STRIDE
    }

    fun draw(model: FloatArray, view: FloatArray, projection: FloatArray, seconds: Float) {
        val o = outline ?: return
        val f = fill ?: return
        Matrix.multiplyMM(modelView, 0, view, 0, model, 0)
        Matrix.multiplyMM(mvp, 0, projection, 0, modelView, 0)

        // The arrow is the only 3D object and lies flat on the floor: draw it without depth testing,
        // outline first, then the fill on top.
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glUseProgram(program)
        GLES20.glUniformMatrix4fv(mvpUniform, 1, false, mvp, 0)
        GLES20.glUniform1f(timeUniform, seconds)

        GLES20.glUniform4f(colorUniform, 0.086f, 0.078f, 0.102f, 0.88f) // #16141a
        GLES20.glUniform1f(flowUniform, 0f)
        drawMesh(o, outlineCount)

        GLES20.glUniform4f(colorUniform, 1f, 0.835f, 0.31f, 0.96f) // #ffd54f
        GLES20.glUniform1f(flowUniform, 1f)
        drawMesh(f, fillCount)

        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    private fun drawMesh(buffer: FloatBuffer, count: Int) {
        val strideBytes = ArrowMesh.STRIDE * Float.SIZE_BYTES
        buffer.position(0)
        GLES20.glVertexAttribPointer(positionAttr, 3, GLES20.GL_FLOAT, false, strideBytes, buffer)
        buffer.position(3)
        GLES20.glVertexAttribPointer(progressAttr, 1, GLES20.GL_FLOAT, false, strideBytes, buffer)
        buffer.position(0)
        GLES20.glEnableVertexAttribArray(positionAttr)
        GLES20.glEnableVertexAttribArray(progressAttr)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, count)
        GLES20.glDisableVertexAttribArray(positionAttr)
        GLES20.glDisableVertexAttribArray(progressAttr)
    }

    private companion object {
        const val HALF_WIDTH = 0.11f
        const val HEAD_HALF_WIDTH = 0.26f
        const val HEAD_LENGTH = 0.34f
        const val OUTLINE = 0.035f

        const val VERTEX_SHADER = """
            uniform mat4 u_Mvp;
            attribute vec4 a_Position;
            attribute float a_Progress;
            varying float v_Progress;
            void main() {
                v_Progress = a_Progress;
                gl_Position = u_Mvp * a_Position;
            }
        """
        const val FRAGMENT_SHADER = """
            precision mediump float;
            uniform vec4 u_Color;
            uniform float u_Time;
            uniform float u_Flow;
            varying float v_Progress;
            void main() {
                // A soft bright band moving from the tail (0) to the head (1) every 1.6 s.
                float head = fract(u_Time / 1.6) * 1.4 - 0.2;
                float band = 1.0 - smoothstep(0.0, 0.12, abs(v_Progress - head));
                vec3 color = mix(u_Color.rgb, vec3(1.0, 0.96, 0.8), band * 0.55 * u_Flow);
                gl_FragColor = vec4(color, u_Color.a);
            }
        """
    }
}

/** Builds the arrow as a centre-line path plus a triangle list. */
internal object ArrowMesh {
    /** Floats per vertex: x, y, z, progress along the arrow (0 = tail, 1 = tip). */
    const val STRIDE = 4

    private const val TAIL_Z = 0.35f
    private const val TURN_Z = -0.55f
    private const val RADIUS = 0.55f
    private const val EXIT_LENGTH = 0.45f
    private const val STRAIGHT_END_Z = -1.6f
    private const val Y = 0.005f

    /** Centre line in the floor plane, as (x, z) pairs. Left is the mirror image of right. */
    fun path(turn: Turn): List<FloatArray> {
        val points = ArrayList<FloatArray>()
        if (turn == Turn.STRAIGHT) {
            val steps = 8
            for (i in 0..steps) {
                val t = i / steps.toFloat()
                points.add(floatArrayOf(0f, TAIL_Z + (STRAIGHT_END_Z - TAIL_Z) * t))
            }
            return points
        }
        val sign = if (turn == Turn.LEFT) -1f else 1f
        val straightSteps = 4
        for (i in 0 until straightSteps) {
            val t = i / straightSteps.toFloat()
            points.add(floatArrayOf(0f, TAIL_Z + (TURN_Z - TAIL_Z) * t))
        }
        // Quarter circle around (±R, TURN_Z): from heading -z to heading ±x.
        val arcSteps = 14
        for (i in 0..arcSteps) {
            val phi = (PI / 2 * i / arcSteps).toFloat()
            val x = RADIUS - RADIUS * cos(phi)
            val z = TURN_Z - RADIUS * sin(phi)
            points.add(floatArrayOf(sign * x, z))
        }
        val exitSteps = 3
        for (i in 1..exitSteps) {
            val x = RADIUS + EXIT_LENGTH * i / exitSteps
            points.add(floatArrayOf(sign * x, TURN_Z - RADIUS))
        }
        return points
    }

    /**
     * Body = quad strip of half-width [halfWidth] along [path]; head = triangle at the end.
     * [extend] lengthens the tail backwards (used by the outline so it surrounds the fill).
     */
    fun build(path: List<FloatArray>, halfWidth: Float, headHalfWidth: Float, headLength: Float, extend: Float): FloatArray {
        val pts = ArrayList(path)
        if (extend > 0f) {
            val (tx, tz) = direction(pts[0], pts[1])
            pts.add(0, floatArrayOf(pts[0][0] - tx * extend, pts[0][1] - tz * extend))
        }
        // Cumulative length for the progress attribute.
        val cumulative = FloatArray(pts.size)
        for (i in 1 until pts.size) {
            val dx = pts[i][0] - pts[i - 1][0]
            val dz = pts[i][1] - pts[i - 1][1]
            cumulative[i] = cumulative[i - 1] + sqrt(dx * dx + dz * dz)
        }
        val total = cumulative.last() + headLength

        val out = ArrayList<Float>()
        fun vertex(x: Float, z: Float, progress: Float) {
            out.add(x); out.add(Y); out.add(z); out.add(progress)
        }

        val left = Array(pts.size) { FloatArray(2) }
        val right = Array(pts.size) { FloatArray(2) }
        for (i in pts.indices) {
            val a = pts[maxOf(i - 1, 0)]
            val b = pts[minOf(i + 1, pts.size - 1)]
            val (tx, tz) = direction(a, b)
            // Normal in the floor plane, pointing to the right of the travel direction.
            val nx = -tz
            val nz = tx
            left[i][0] = pts[i][0] - nx * halfWidth
            left[i][1] = pts[i][1] - nz * halfWidth
            right[i][0] = pts[i][0] + nx * halfWidth
            right[i][1] = pts[i][1] + nz * halfWidth
        }
        for (i in 0 until pts.size - 1) {
            val p0 = cumulative[i] / total
            val p1 = cumulative[i + 1] / total
            vertex(left[i][0], left[i][1], p0)
            vertex(right[i][0], right[i][1], p0)
            vertex(left[i + 1][0], left[i + 1][1], p1)
            vertex(right[i][0], right[i][1], p0)
            vertex(right[i + 1][0], right[i + 1][1], p1)
            vertex(left[i + 1][0], left[i + 1][1], p1)
        }

        // Arrow head.
        val end = pts.last()
        val (tx, tz) = direction(pts[pts.size - 2], end)
        val nx = -tz
        val nz = tx
        val baseProgress = cumulative.last() / total
        // The outline's head starts a little earlier so it also borders the back edge of the head.
        val bx = end[0] - tx * extend
        val bz = end[1] - tz * extend
        vertex(bx - nx * headHalfWidth, bz - nz * headHalfWidth, baseProgress)
        vertex(bx + nx * headHalfWidth, bz + nz * headHalfWidth, baseProgress)
        vertex(end[0] + tx * headLength, end[1] + tz * headLength, 1f)

        return out.toFloatArray()
    }

    private fun direction(a: FloatArray, b: FloatArray): Pair<Float, Float> {
        val dx = b[0] - a[0]
        val dz = b[1] - a[1]
        val len = sqrt(dx * dx + dz * dz).coerceAtLeast(1e-6f)
        return Pair(dx / len, dz / len)
    }
}
