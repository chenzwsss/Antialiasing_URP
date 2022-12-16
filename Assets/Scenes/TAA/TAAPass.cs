using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TAAPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "TAA";

    static readonly int TempTargetId = Shader.PropertyToID("_TempTargetTaa");

    TAA taa;
    Material taaMaterial;
    RenderTargetIdentifier currentTarget;

    public TAAPass(RenderPassEvent evt, CustomPostProcessData customPostProcessData)
    {
        renderPassEvent = evt;

        var shader = customPostProcessData.shaders.taaShader;
        if (shader == null)
        {
            Debug.LogError("Shader not found.");
            return;
        }

        taaMaterial = CoreUtils.CreateEngineMaterial(shader);
        taaMaterial.hideFlags = HideFlags.HideAndDontSave;
    }

    public void Setup(RenderTargetIdentifier current)
    {
        currentTarget = current;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (taaMaterial == null)
        {
            Debug.LogError("Material not created.");
            return;
        }

        if (!renderingData.cameraData.postProcessEnabled)
        {
            return;
        }

        var stack = VolumeManager.instance.stack;
        taa = stack.GetComponent<TAA>();

        if (taa == null)
        {
            return;
        }

        if (!taa.IsActive())
        {
            return;
        }

        var cmd = CommandBufferPool.Get(k_RenderTag);

        Render(cmd, ref renderingData);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTargetIdentifier source = currentTarget;
        int destination = TempTargetId;

        int width = renderingData.cameraData.camera.scaledPixelWidth;
        int height = renderingData.cameraData.camera.scaledPixelHeight;

        int shaderPass = 0;

        cmd.GetTemporaryRT(destination, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.Default);

        cmd.Blit(source, destination);
        cmd.Blit(destination, source, taaMaterial, shaderPass);

        cmd.ReleaseTemporaryRT(destination);
    }

    public void Cleanup()
    {

    }
}
