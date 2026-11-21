using UnityEngine;

public sealed partial class KinseiWorld
{
    Camera stageCamera;
    RenderTexture marqueePicture;
    Material marqueeGlass;
    float nextMarqueeFrame;

    void BuildMarquee()
    {
        var centre=new Vector3(5.5f,2.08f,-8.59f);
        Cushion("金星の街頭受像機",centre,new Vector3(2.10f,1.55f,.28f),oxblood,transform);
        Cushion("街頭テレビの金縁",centre-Vector3.forward*.132f,new Vector3(1.88f,1.35f,.10f),brass,transform);
        Cushion("街頭テレビのゴムマスク",centre-Vector3.forward*.182f,new Vector3(1.77f,1.24f,.073f),dark,transform);
        marqueeGlass=new Material(Resources.Load<Shader>("KinseiMarqueeTube")){name="金星・表通りの管面"};
        var face=Surface("金星の生中継画面",tubeGlass,marqueeGlass,transform);
        face.transform.localPosition=centre-Vector3.forward*.218f;face.transform.localScale=Vector3.one*2.91f;
        marqueePicture=new RenderTexture(512,384,16){name="入口の舞台中継",filterMode=FilterMode.Bilinear};
        var lens=new GameObject("金星・舞台中継カメラ");lens.transform.SetParent(transform,false);
        lens.transform.localPosition=new Vector3(-3.78f,1.83f,1.21f);
        lens.transform.LookAt(transform.TransformPoint(new Vector3(-4.12f,1.60f,4.04f)));
        stageCamera=lens.AddComponent<Camera>();stageCamera.enabled=false;
        stageCamera.clearFlags=CameraClearFlags.SolidColor;stageCamera.backgroundColor=new Color(.055f,.019f,.028f);
        stageCamera.fieldOfView=46;stageCamera.nearClipPlane=.08f;stageCamera.farClipPlane=14;
        stageCamera.targetTexture=marqueePicture;
        marqueeGlass.mainTexture=standby;
        var solo=LightAt("舞台前の歌手用スポット",new Vector3(-5.56f,3.52f,1.41f),new Color(1,.88f,.76f),3.15f,5.3f);
        solo.type=LightType.Spot;solo.spotAngle=44;solo.innerSpotAngle=24;
        solo.transform.LookAt(transform.TransformPoint(new Vector3(-4.94f,1.83f,3.64f)));
    }

    public void UpdateMarquee(bool performing,bool visible,float time)
    {
        if(dawnBranch!=0)return;
        if(!performing){if(marqueeGlass.mainTexture!=standby)marqueeGlass.mainTexture=standby;return;}
        if(!visible || time<nextMarqueeFrame || SystemInfo.graphicsDeviceType==UnityEngine.Rendering.GraphicsDeviceType.Null)return;
        stageCamera.Render();marqueeGlass.mainTexture=marqueePicture;
        nextMarqueeFrame=time+.08f;
    }

    void ReleaseMarquee()
    {
        if(marqueePicture){marqueePicture.Release();Destroy(marqueePicture);}
        if(marqueeGlass)Destroy(marqueeGlass);
    }
}
