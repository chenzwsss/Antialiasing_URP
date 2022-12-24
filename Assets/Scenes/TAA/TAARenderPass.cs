using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TAARenderPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "TAA Render Pass";

    static readonly int HistoryTexId = Shader.PropertyToID("_HistoryTex");
    static readonly int JitterId = Shader.PropertyToID("_Jitter");
    static readonly int SharpnessId = Shader.PropertyToID("_Sharpness");

    Material taaMaterial;
    RenderTargetIdentifier currentTarget;

    // Ping-pong between two history textures as we can't read & write the same target in the
    // same pass
    const int k_NumHistoryTextures = 2;
    readonly RenderTexture[] m_HistoryTextures;

    int m_HistoryWrite = 0;

    TAAData m_TaaData;

    public TAARenderPass(RenderPassEvent evt, ScriptableRenderPassInput passInput, CustomPostProcessData customPostProcessData)
    {
        renderPassEvent = evt;

        ConfigureInput(passInput);

        var shader = customPostProcessData.shaders.taaShader;
        if (shader == null)
        {
            Debug.LogError("Shader not found.");
            return;
        }

        taaMaterial = CoreUtils.CreateEngineMaterial(shader);
        taaMaterial.hideFlags = HideFlags.HideAndDontSave;

        m_HistoryTextures = new RenderTexture[k_NumHistoryTextures];
    }

    public void Setup(RenderTargetIdentifier current, TAAData taaData)
    {
        currentTarget = current;
        m_TaaData = taaData;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (taaMaterial == null)
        {
            Debug.LogError("Material not created.");
            return;
        }

        var cmd = CommandBufferPool.Get(k_RenderTag);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        Render(cmd, ref renderingData);

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTargetIdentifier source = currentTarget;

        int indexRead = m_HistoryWrite;
        m_HistoryWrite = (++m_HistoryWrite) % 2;

        int width = renderingData.cameraData.camera.scaledPixelWidth;
        int height = renderingData.cameraData.camera.scaledPixelHeight;

        int shaderPass = 0;

        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.DefaultHDR);
        var historyRead = CheckHistory(indexRead, descriptor);
        var historyWrite = CheckHistory(m_HistoryWrite, descriptor);

        var stack = VolumeManager.instance.stack;
        var taa = stack.GetComponent<TAA>();

        taaMaterial.SetVector(JitterId, m_TaaData.jitter);
        taaMaterial.SetFloat(SharpnessId, taa.sharpness.value);
        taaMaterial.SetTexture(HistoryTexId, historyRead);
        cmd.Blit(source, historyWrite, taaMaterial, shaderPass);
        cmd.Blit(historyWrite, source);
    }

    RenderTexture CheckHistory(int id, RenderTextureDescriptor descriptor)
    {
        var rt = m_HistoryTextures[id];

        if (rt != null && (rt.width != descriptor.width || rt.height != descriptor.height))
        {
            RenderTexture.ReleaseTemporary(rt);
            rt = null;
        }

        if (rt == null)
        {
            rt = RenderTexture.GetTemporary(descriptor.width, descriptor.height, 0, descriptor.colorFormat);
            rt.name = "Temporal Anti-aliasing History id #" + id;
            rt.filterMode = FilterMode.Bilinear;
            m_HistoryTextures[id] = rt;
        }

        return m_HistoryTextures[id];
    }

    public void Cleanup()
    {
        if (m_HistoryTextures != null)
        {
            for (int i = 0; i < m_HistoryTextures.Length; i++)
            {
                if (m_HistoryTextures[i] == null)
                    continue;

                RenderTexture.ReleaseTemporary(m_HistoryTextures[i]);
                m_HistoryTextures[i] = null;
            }
        }
    }
}
