using UnityEngine;

public class TAAUtils
{
    const int k_SampleCount = 8;
    static int sampleIndex { get; set; }

    public static float HaltonSeqGet(int index, int radix)
    {
        float result = 0f;
        float fraction = 1f / (float)radix;

        while (index > 0)
        {
            result += (float)(index % radix) * fraction;

            index /= radix;
            fraction /= (float)radix;
        }

        return result;
    }

    public static Vector2 GenerateRandomOffset()
    {
        var offset = new Vector2(
            HaltonSeqGet((sampleIndex & 1023) + 1, 2) - 0.5f,
            HaltonSeqGet((sampleIndex & 1023) + 1, 3) - 0.5f
        );

        if (++sampleIndex >= k_SampleCount)
            sampleIndex = 0;

        return offset;
    }

    /// <summary>
    /// Gets a jittered perspective projection matrix for a given camera.
    /// </summary>
    /// <param name="camera">The camera to build the projection matrix for</param>
    /// <param name="offset">The jitter offset</param>
    /// <returns>A jittered projection matrix</returns>
    public static Matrix4x4 GetJitteredPerspectiveProjectionMatrix(Camera camera, Vector2 offset)
    {
        float near = camera.nearClipPlane;
        float far = camera.farClipPlane;

        float vertical = Mathf.Tan(0.5f * Mathf.Deg2Rad * camera.fieldOfView) * near;
        float horizontal = vertical * camera.aspect;

        offset.x *= horizontal / (0.5f * camera.pixelWidth);
        offset.y *= vertical / (0.5f * camera.pixelHeight);

        var matrix = camera.projectionMatrix;

        matrix[0, 2] += offset.x / horizontal;
        matrix[1, 2] += offset.y / vertical;

        return matrix;
    }

    /// <summary>
    /// Gets a jittered orthographic projection matrix for a given camera.
    /// </summary>
    /// <param name="camera">The camera to build the orthographic matrix for</param>
    /// <param name="offset">The jitter offset</param>
    /// <returns>A jittered projection matrix</returns>
    public static Matrix4x4 GetJitteredOrthographicProjectionMatrix(Camera camera, Vector2 offset)
    {
        float vertical = camera.orthographicSize;
        float horizontal = vertical * camera.aspect;

        offset.x *= horizontal / (0.5f * camera.pixelWidth);
        offset.y *= vertical / (0.5f * camera.pixelHeight);

        float left = offset.x - horizontal;
        float right = offset.x + horizontal;
        float top = offset.y + vertical;
        float bottom = offset.y - vertical;

        return Matrix4x4.Ortho(left, right, bottom, top, camera.nearClipPlane, camera.farClipPlane);
    }
}
