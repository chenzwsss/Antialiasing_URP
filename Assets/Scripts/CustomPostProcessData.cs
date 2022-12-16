#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
#endif
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public class CustomPostProcessData : ScriptableObject
{
#if UNITY_EDITOR
    [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]
    internal class CreatePostProcessDataAsset : EndNameEditAction
    {
        public override void Action(int instanceId, string pathName, string resourceFile)
        {
            var instance = CreateInstance<CustomPostProcessData>();
            AssetDatabase.CreateAsset(instance, pathName);
            ResourceReloader.ReloadAllNullIn(instance, UniversalRenderPipelineAsset.packagePath);
            Selection.activeObject = instance;
        }
    }

    [MenuItem("Assets/Create/Rendering/AntialiasingURP/Custom Post-process Data", priority = CoreUtils.assetCreateMenuPriority3)]
    static void CreatePostProcessData()
    {
        ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreatePostProcessDataAsset>(), "CustomPostProcessData.asset", null, null);
    }
#endif

    [Serializable, ReloadGroup]
    public sealed class ShaderResources
    {
        public Shader zoomBlurShader;
        public Shader fxaaShader;
        public Shader taaShader;
    }

    public ShaderResources shaders;
}
