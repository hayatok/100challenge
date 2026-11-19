using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Evac.Editor
{
    public static class CampaignBuild
    {
        const string Scene = "Assets/Scenes/Dispatch.unity";
        static void Configure()
        {
            if (!File.Exists(Scene))
            {
                var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
                new GameObject("Evacuation Control").AddComponent<GameSession>();
                EditorSceneManager.SaveScene(scene,Scene);
            }
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(Scene,true)};
            PlayerSettings.companyName="100challenge";
            PlayerSettings.productName="避難指令";
            PlayerSettings.bundleVersion="0.2.0";
            var icon=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/WebGLTemplates/Dispatch/train-512.png");
            if(icon!=null)PlayerSettings.SetIcons(UnityEditor.Build.NamedBuildTarget.Unknown,new[]{icon},IconKind.Application);
            PlayerSettings.defaultScreenWidth=1280; PlayerSettings.defaultScreenHeight=720;
            PlayerSettings.fullScreenMode=FullScreenMode.Windowed;
            PlayerSettings.resizableWindow=true;
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToLandscapeRight=true;
            PlayerSettings.allowedAutorotateToLandscapeLeft=true;
            PlayerSettings.allowedAutorotateToPortrait=false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown=false;
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.Standalone,"jp.hayatok.evacuationcontrol");
            PlayerSettings.WebGL.compressionFormat=WebGLCompressionFormat.Gzip;
            PlayerSettings.WebGL.decompressionFallback=true;
            PlayerSettings.WebGL.nameFilesAsHashes=true;
            PlayerSettings.WebGL.template="PROJECT:Dispatch";
            var g=AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset");
            if(g.Length>0)
            {
                var so=new SerializedObject(g[0]);
                var strip=so.FindProperty("m_InstancingStripping");
                // The crowd is drawn through Graphics.DrawMeshInstanced at runtime.
                // Unity's internal InstancingStrippingMode.KeepAll has value 2.
                if(strip!=null){strip.intValue=2;so.ApplyModifiedPropertiesWithoutUndo();}
            }
            AssetDatabase.SaveAssets();
        }
        [MenuItem("避難指令/Windows ビルド")]
        public static void Windows() => Build(BuildTarget.StandaloneWindows64,"Builds/Windows/EvacuationControl.exe");
        [MenuItem("避難指令/モバイルWeb ビルド")]
        public static void Web() => Build(BuildTarget.WebGL,"Builds/Web");
        public static void WebInspection() => Build(BuildTarget.WebGL,"Builds/WebInspection",true);
        public static void Inspection() => Build(BuildTarget.StandaloneWindows64,"Builds/Inspection/EvacuationInspection.exe",true);
        public static void VerifySimulation()
        {
            Configure();
            Debug.Log(SimulationVerification.Run());
        }
        static void Build(BuildTarget platform,string destination,bool inspection=false)
        {
            Configure();
            Directory.CreateDirectory(platform==BuildTarget.WebGL?destination:Path.GetDirectoryName(destination));
            var result=BuildPipeline.BuildPlayer(new BuildPlayerOptions {scenes=new[]{Scene},locationPathName=destination,target=platform,
                extraScriptingDefines=inspection ? new[]{platform==BuildTarget.WebGL?"EVAC_WEB_TEST":"EVAC_INSPECTION"} : Array.Empty<string>(),
                options=BuildOptions.CompressWithLz4});
            if(result.summary.result!=BuildResult.Succeeded)throw new Exception("Build failed: "+result.summary.result+" with "+result.summary.totalErrors+" errors");
            Debug.Log($"CAMPAIGN BUILD OK {platform} {result.summary.totalSize} bytes");
        }
    }
}
