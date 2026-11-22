using UnityEditor;
using UnityEngine;

public sealed class KinseiSurfaceImporter : AssetPostprocessor
{
    void OnPreprocessTexture()
    {
        if(!assetPath.Contains("/KinseiSurfaces/")) return;
        var t=(TextureImporter)assetImporter;
        t.wrapMode=TextureWrapMode.Repeat; t.anisoLevel=8; t.mipmapEnabled=true;
        if(assetPath.EndsWith("_nor_gl.jpg",System.StringComparison.OrdinalIgnoreCase)) {
            t.textureType=TextureImporterType.NormalMap;t.sRGBTexture=false;
        }
    }
}

