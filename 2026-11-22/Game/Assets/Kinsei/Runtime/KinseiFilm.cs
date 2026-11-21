using UnityEngine;

[RequireComponent(typeof(Camera))]
public sealed class KinseiFilm : MonoBehaviour
{
    Material material;
    void Awake()
    {
        var shader=Resources.Load<Shader>("KinseiFilm");
        if(shader!=null && shader.isSupported)material=new Material(shader);
    }
    void OnRenderImage(RenderTexture source,RenderTexture destination)
    {
        if(material==null){Graphics.Blit(source,destination);return;}
        int width=Mathf.Max(1,source.width/4), height=Mathf.Max(1,source.height/4);
        var a=RenderTexture.GetTemporary(width,height,0,RenderTextureFormat.DefaultHDR);
        var b=RenderTexture.GetTemporary(width,height,0,RenderTextureFormat.DefaultHDR);
        a.filterMode=b.filterMode=FilterMode.Bilinear;
        Graphics.Blit(source,a,material,0);
        material.SetFloat("_Spread",1.3f); Graphics.Blit(a,b,material,1);
        material.SetFloat("_Spread",3.2f); Graphics.Blit(b,a,material,1);
        material.SetTexture("_Halation",a); material.SetFloat("_Grain",.002f);
        Graphics.Blit(source,destination,material,2);
        RenderTexture.ReleaseTemporary(a);RenderTexture.ReleaseTemporary(b);
    }
    void OnDestroy(){if(material!=null)Destroy(material);}
}

