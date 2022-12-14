using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class FXAAPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "FXAA";

    static readonly int TempTargetId = Shader.PropertyToID("_TempTargetFxaa");
    static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    static readonly int FxaaQualityEdgeThresholdMin = Shader.PropertyToID("_FxaaQualityEdgeThresholdMin");
    static readonly int FxaaQualityEdgeThreshold = Shader.PropertyToID("_FxaaQualityEdgeThreshold");
    static readonly int FxaaQualitySubpix = Shader.PropertyToID("_FxaaQualitySubpix");

    FXAA fxaa;
    Material fxaaMaterial;
    RenderTargetIdentifier currentTarget;

    public FXAAPass(RenderPassEvent evt, CustomPostProcessData customPostProcessData)
    {
        renderPassEvent = evt;

        var shader = customPostProcessData.shaders.fxaaShader;
        if (shader == null)
        {
            Debug.LogError("Shader not found.");
            return;
        }

        fxaaMaterial = CoreUtils.CreateEngineMaterial(shader);
        fxaaMaterial.hideFlags = HideFlags.HideAndDontSave;
    }

    public void Setup(RenderTargetIdentifier currentTarget)
    {
        this.currentTarget = currentTarget;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (fxaaMaterial == null)
        {
            Debug.LogError("Material not created.");
            return;
        }

        if (!renderingData.cameraData.postProcessEnabled)
        {
            return;
        }

        var stack = VolumeManager.instance.stack;
        fxaa = stack.GetComponent<FXAA>();

        if (fxaa == null)
        {
            return;
        }

        if (!fxaa.IsActive())
        {
            return;
        }

        var cmd = CommandBufferPool.Get(k_RenderTag);
        Render(cmd, ref renderingData);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
    public void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var cameraData = renderingData.cameraData;
        var source = currentTarget;
        var destination = TempTargetId;

        fxaaMaterial.SetFloat(FxaaQualityEdgeThresholdMin, fxaa.fxaaQualityEdgeThresholdMin.value);
        fxaaMaterial.SetFloat(FxaaQualityEdgeThreshold, fxaa.fxaaQualityEdgeThreshold.value);
        fxaaMaterial.SetFloat(FxaaQualitySubpix, fxaa.fxaaQualitySubpix.value);

        int width = cameraData.camera.scaledPixelWidth;
        int height = cameraData.camera.scaledPixelHeight;

        cmd.GetTemporaryRT(TempTargetId, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.Default);

        cmd.Blit(source, destination);
        cmd.Blit(destination, source, fxaaMaterial, 0);

        cmd.ReleaseTemporaryRT(destination);
    }
}
