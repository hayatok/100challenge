#if UNITY_EDITOR
using UnityEditor;
public sealed class KinseiSkinImporter : AssetPostprocessor
{
    void OnPreprocessModel()
    {
        if(!assetPath.Contains("Resources/KinseiCast/"))return;
        var model=(ModelImporter)assetImporter;model.isReadable=true;model.importAnimation=false;model.materialImportMode=ModelImporterMaterialImportMode.None;model.importTangents=ModelImporterTangents.CalculateMikk;
    }
    void OnPreprocessTexture()
    {
        const string prefix="Resources/KinseiCast/";
        if(!assetPath.Contains(prefix))return;
        var texture=(TextureImporter)assetImporter;
        bool skin=assetPath.Contains(prefix+"Skin");
        texture.maxTextureSize=skin?2048:512;
        texture.mipmapEnabled=true;
        texture.wrapMode=skin?UnityEngine.TextureWrapMode.Clamp:UnityEngine.TextureWrapMode.Repeat;
        texture.filterMode=UnityEngine.FilterMode.Trilinear;
        if(assetPath.EndsWith("Normal.png"))
        {
            texture.textureType=TextureImporterType.NormalMap;
            texture.sRGBTexture=false;
        }
        else if(assetPath.EndsWith("Specular.png")) texture.sRGBTexture=false;
    }
}
#endif
