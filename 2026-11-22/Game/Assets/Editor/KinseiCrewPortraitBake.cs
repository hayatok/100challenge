using System;
using System.IO;
using UnityEditor;
using UnityEngine;

// Render the same wardrobe, head variants and proportions used by the live roster.
[InitializeOnLoad]
public static class KinseiCrewPortraitBake
{
    const string Pending = "KinseiCrewPortraitBake.pending";
    const int Layer = 30, Size = 192;
    static KinseiActor[] actors;
    static int spawnFrame;

    static KinseiCrewPortraitBake()
    {
        if (SessionState.GetBool(Pending, false)) EditorApplication.update += WhenReady;
    }

    public static void Run()
    {
        SessionState.SetBool(Pending, true);
        EditorApplication.update -= WhenReady;
        EditorApplication.update += WhenReady;
        EditorApplication.EnterPlaymode();
    }

    static void WhenReady()
    {
        if (!EditorApplication.isPlaying || EditorApplication.isCompiling) return;
        try
        {
            if (actors == null)
            {
                actors = new KinseiActor[6];
                for (int i = 0; i < actors.Length; i++)
                {
                    var root = new GameObject("Portrait " + i);
                    root.transform.position = new Vector3(4 * i, 100, 0);
                    root.transform.rotation = Quaternion.Euler(0, -10 + (i % 4) * 7, 0);
                    actors[i] = root.AddComponent<KinseiActor>();
                    actors[i].Init(i == 0 ? "tatsu" : "ally", i);
                    foreach (Transform part in root.GetComponentsInChildren<Transform>(true))
                        part.gameObject.layer = Layer;
                }
                spawnFrame = Time.frameCount;
                return;
            }
            if (Time.frameCount <= spawnFrame + 1) return;
            RenderStrip();
            Debug.Log("KINSEI_PORTRAITS_PASS");
            Finish(0);
        }
        catch (Exception e) { Debug.LogException(e); Finish(1); }
    }

    static void Finish(int status)
    {
        EditorApplication.update -= WhenReady;
        SessionState.EraseBool(Pending);
        EditorApplication.Exit(status);
    }

    static void LightAt(Vector3 toward, Color tint, float intensity)
    {
        var light = new GameObject("Portrait studio").AddComponent<Light>();
        light.type = LightType.Directional;
        light.transform.rotation = Quaternion.LookRotation(toward);
        light.color = tint;
        light.intensity = intensity;
        light.cullingMask = 1 << Layer;
    }

    static void RenderStrip()
    {
        foreach (Light sceneLamp in UnityEngine.Object.FindObjectsByType<Light>(FindObjectsSortMode.None))
            sceneLamp.cullingMask &= ~(1 << Layer);
        RenderSettings.fog = false;
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(.26f, .27f, .29f);
        LightAt(new Vector3(.55f, -.48f, -1), new Color(1, .89f, .77f), 1.00f);
        LightAt(new Vector3(-1, -.1f, -.35f), new Color(.63f, .83f, 1), .42f);
        LightAt(new Vector3(-.4f, -.2f, 1), new Color(.99f, .83f, .62f), .73f);
        var camera = new GameObject("Portrait camera").AddComponent<Camera>();
        camera.enabled = false;
        camera.cullingMask = 1 << Layer;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(.19f, .27f, .30f);
        camera.orthographic = true;
        camera.orthographicSize = .226f;
        camera.nearClipPlane = .05f;
        camera.farClipPlane = 3f;
        camera.allowHDR = false;
        var target = new RenderTexture(Size, Size, 24, RenderTextureFormat.ARGB32) { antiAliasing = 4 };
        var atlas = new Texture2D(Size * actors.Length, Size, TextureFormat.RGB24, false);
        camera.targetTexture = target;
        camera.aspect = 1;
        for (int i = 0; i < actors.Length; i++)
        {
            Vector3 center = actors[i].EyePosition - Vector3.up * .074f;
            camera.transform.position = center + new Vector3(.055f, .014f, 1f);
            camera.transform.LookAt(center);
            camera.Render();
            RenderTexture.active = target;
            atlas.ReadPixels(new Rect(0, 0, Size, Size), i * Size, 0);
        }
        RenderTexture.active = null;
        camera.targetTexture = null;
        target.Release();
        atlas.Apply();
        File.WriteAllBytes(Path.Combine(Application.dataPath, "Resources/KinseiCrewPortraits.png"), atlas.EncodeToPNG());
    }
}
