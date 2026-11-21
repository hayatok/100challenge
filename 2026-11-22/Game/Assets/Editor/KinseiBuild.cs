using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class KinseiBuild
{
    const string ScenePath = "Assets/Kinsei/Kinsei.unity";

    [MenuItem("金星/Windows プレイヤーをビルド")]
    public static void Windows()
    {
        if (!File.Exists(ScenePath))
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, ScenePath);
        }
        // Runtime-created meshes require the full Standard shader family in the player.
        KeepMaterial("KinseiSurface","Standard");
        KeepMaterial("KinseiSign","Unlit/Texture");
        KeepMaterial("KinseiGlow","Standard","_EMISSION");
        KeepMaterial("KinseiCutPaper","Standard","_ALPHATEST_ON");
        KeepMaterial("KinseiRelief","Standard","_NORMALMAP");
        KeepMaterial("KinseiSkin","Standard (Specular setup)","_NORMALMAP","_SPECGLOSSMAP");
        foreach(string guid in AssetDatabase.FindAssets("t:Texture2D",new[]{"Assets/Resources/KinseiSurfaces"}))
        {
            string asset=AssetDatabase.GUIDToAssetPath(guid);
            if(!asset.EndsWith("_nor_gl.jpg",StringComparison.OrdinalIgnoreCase))continue;
            var importer=(TextureImporter)AssetImporter.GetAtPath(asset);
            if(importer.textureType!=TextureImporterType.NormalMap) {
                importer.textureType=TextureImporterType.NormalMap; importer.sRGBTexture=false;
                importer.SaveAndReimport();
            }
        }
        EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        PlayerSettings.companyName = "Yoimachi";
        PlayerSettings.productName = "金星の一夜";
        PlayerSettings.bundleVersion = "1.3.0";
        PlayerSettings.defaultScreenWidth = 1600;
        PlayerSettings.defaultScreenHeight = 900;
        PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
        PlayerSettings.resizableWindow = true;
        PlayerSettings.colorSpace = ColorSpace.Linear;
        PlayerSettings.runInBackground = false;
        AssetDatabase.SaveAssets();
        string path = Path.GetFullPath("../Builds/Windows/Kinsei.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        var result = BuildPipeline.BuildPlayer(new[] { ScenePath }, path, BuildTarget.StandaloneWindows64, BuildOptions.CompressWithLz4);
        if (result.summary.result != BuildResult.Succeeded)
            throw new InvalidOperationException(result.summary.result + " / " + result.summary.totalErrors);
        Debug.Log("KINSEI_WINDOWS " + path + " " + result.summary.totalSize);
    }

    static void KeepMaterial(string name,string shaderName,params string[] features)
    {
        string path = "Assets/Resources/" + name + ".mat";
        if (File.Exists(path)) return;
        var shader = Shader.Find(shaderName);
        if (shader == null) throw new InvalidOperationException("Missing build shader " + shaderName);
        var material = new Material(shader);
        foreach (string feature in features) material.EnableKeyword(feature);
        AssetDatabase.CreateAsset(material,path);
    }
}
