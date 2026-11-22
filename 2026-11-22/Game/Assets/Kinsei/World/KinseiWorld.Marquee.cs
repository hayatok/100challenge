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
        var enamel=nightAssets.Keep(Mat("金星町内回線・象牙色の焼付琺瑯","#CCBEA3",.22f,.50f));
        var enamelMap=Resources.Load<Texture2D>("KinseiRainStreet/Enamel");
        if(enamelMap){enamel.mainTexture=enamelMap;enamel.color=Color.white;}
        Cushion("金星の街頭受像機",centre,new Vector3(2.10f,1.55f,.28f),enamel,transform,true);
        Cushion("街頭テレビの金縁",centre-Vector3.forward*.132f,new Vector3(1.88f,1.35f,.10f),brass,transform);
        Cushion("街頭テレビのゴムマスク",centre-Vector3.forward*.182f,new Vector3(1.77f,1.24f,.073f),dark,transform);
        marqueeGlass=new Material(Resources.Load<Shader>("KinseiMarqueeTube")){name="金星・表通りの管面"};
        var face=Surface("金星の生中継画面",tubeGlass,marqueeGlass,transform);
        face.transform.localPosition=centre-Vector3.forward*.218f;face.transform.localScale=Vector3.one*2.91f;
        face.AddComponent<BoxCollider>();
        BuildMarqueeControls(centre,enamel);
        BuildMarqueePaving();
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

    void BuildMarqueePaving()
    {
        var granite=nightAssets.Keep(Mat("金星玄関の洗い出し平板","#766E61",.07f,.34f));
        granite.mainTexture=Resources.Load<Texture2D>("KinseiWestBath/Terrazzo");
        var edge=nightAssets.Keep(new Material(granite){name="踏み減った縁石",color=new Color(.51f,.48f,.43f)});
        var iron=nightAssets.Keep(Mat("側溝の鋳鉄","#474641",.43f,.37f));
        var paving=new NightGeometry();var kerb=new NightGeometry();var drain=new NightGeometry();
        foreach(int side in new[]{-1,1}) {
            float cx=side*7.5f;
            for(int row=0;row<8;row++) {
                float z=-11.66f+(row+.5f)*.445f;
                for(int col=0;col<6;col++)
                    paving.Block(new Vector3(cx-1.5f+(col+.5f)*.5f,.184f,z),new Vector3(.492f,.018f,.436f),.20f);
            }
            for(int i=0;i<6;i++) {
                float x=cx-1.5f+(i+.5f)*.5f;
                kerb.Block(new Vector3(x,.10f,-11.785f),new Vector3(.491f,.19f,.255f),.22f);
            }
            for(int i=0;i<8;i++) {
                float z=-11.65f+(i+.5f)*.443f;
                kerb.Block(new Vector3(cx-side*1.49f,.091f,z),new Vector3(.024f,.175f,.435f),.22f);
            }
            Box("雨樋の落ち口",new Vector3(cx+.48f,-.014f,-12.04f),new Vector3(.73f,.015f,.237f),dark);
            for(int j=0;j<18;j++)
                drain.Block(new Vector3(cx+.134f+j*.04f,-.002f,-12.04f),new Vector3(.016f,.021f,.227f));
            for(int j=0;j<2;j++)
                drain.Block(new Vector3(cx+.474f,-.001f,-12.04f+(j-.5f)*.212f),new Vector3(.725f,.024f,.019f));
        }
        paving.Upload(nightAssets.Root,granite,nightAssets);kerb.Upload(nightAssets.Root,edge,nightAssets);
        drain.Upload(nightAssets.Root,iron,nightAssets);
    }

    void BuildMarqueeControls(Vector3 centre,Material enamel)
    {
        Vector3 fascia=centre+new Vector3(0,-.86f,-.041f);
        Cushion("回線切替器の琺瑯ケース",fascia,new Vector3(1.95f,.35f,.25f),enamel,transform,true);
        float front=fascia.z-.14f;
        var bakelite=nightAssets.Keep(Mat("こげ茶のベークライト","#514037",.045f,.38f));
        var gauze=nightAssets.Keep(Mat("拡声器の濃色クロス","#51483F",.08f,.22f));
        var weave=Resources.Load<Texture2D>("KinseiRainStreet/Grille");
        if(weave){gauze.mainTexture=weave;gauze.mainTextureScale=new Vector2(2.5f,1);gauze.color=Color.white;}
        Cushion("内張りの織布",new Vector3(centre.x+.24f,fascia.y,front),new Vector3(.54f,.19f,.018f),gauze,transform);
        for(int i=0;i<5;i++)
            Box("スピーカーの保護桟",new Vector3(centre.x+.24f,fascia.y-.079f+i*.039f,front-.022f),
                new Vector3(.54f,.010f,.018f),brass);
        for(int i=0;i<2;i++){
            float x=centre.x-.67f+i*.31f;
            Vector3 dial=new Vector3(x,fascia.y,front-.009f);
            Cylinder("目盛板",dial,.106f,.018f,brass).transform.localRotation=Quaternion.Euler(90,0,0);
            Cylinder("黒い切替つまみ",dial+Vector3.back*.026f,.066f,.055f,bakelite).transform.localRotation=Quaternion.Euler(90,0,0);
            for(int j=0;j<9;j++){
                float a=Mathf.Lerp(-120,120,j/8f);
                var v=Quaternion.Euler(0,0,a)*Vector3.up;
                Rail(dial+v*.083f+Vector3.back*.013f,dial+v*.094f+Vector3.back*.013f,.002f,dark);
            }
            var lever=Box("指先で回す耳",dial+Vector3.back*.061f,new Vector3(.024f,.107f,.020f),bakelite);
            lever.transform.localRotation=Quaternion.Euler(0,0,i==0?33:-14);
        }
        Vector3 display=new Vector3(centre.x+.74f,fascia.y,front);
        Box("回線番号の真鍮枠",display,new Vector3(.157f,.187f,.021f),brass);
        Box("番号窓の繰出し札",display+Vector3.back*.017f,new Vector3(.136f,.165f,.019f),dark);
        Text("3",display+Vector3.back*.032f,.124f,cream,0);
        for(int i=0;i<2;i++){
            Vector3 a=new Vector3(centre.x+.70f+i*.084f,fascia.y-.16f,fascia.z);
            Vector3 bend=a+Vector3.down*(.24f+i*.073f);
            Rail(a,bend,.017f,brass);
            Part("配線管のエルボ",PrimitiveType.Sphere,bend,new Vector3(.041f,.041f,.041f),brass);
            Rail(bend,bend+Vector3.right*(1.05f-i*.084f),.017f,brass);
        }
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
