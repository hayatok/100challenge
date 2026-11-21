using UnityEngine;

// All morning-only set dressing is built once on first entry. Night geometry retains its original materials.
public sealed partial class KinseiWorld
{
    Transform dawnRoot;
    Material dawnSky, dawnHome;
    Light dawnSun;
    Renderer[] dawnCards;
    Renderer dawnTicket;
    Material dawnRelayPaper, dawnOfficePaper;
    Texture dawnAir, dawnSignal, nightAirTex, nightExchangeTex, nightMarqueeTex;
    Color nightSky, nightEquator, nightGround, nightHaze, nightHomeEmission;
    Texture nightExchangeEmission;
    Color nightExchangeColour;
    bool nightExchangeLit;
    float nightDensity, tubeFade;
    int dawnBranch, dawnStep;
    Light[] dawnLamps;
    float[] nightPower;
    float nightTubeGain;
    static readonly int TubeGain=Shader.PropertyToID("_ProgrammeGain");
    static readonly int PrintST=Shader.PropertyToID("_MainTex_ST");
    MaterialPropertyBlock dawnPrintBlock;

    public void SetDawnProgramme(int branch,int step)
    {
        branch=Mathf.Clamp(branch,0,2);
        step=branch==0?0:Mathf.Clamp(step,0,2);
        if(branch==dawnBranch && step==dawnStep)return;
        if(branch==0){LeaveDawn();return;}
        if(nightAssets==null || !nightAssets.Root)return;
        if(!dawnRoot)BuildDawnShopfronts();
        if(dawnBranch==0)
        {
            nightSky=RenderSettings.ambientSkyColor;nightEquator=RenderSettings.ambientEquatorColor;
            nightGround=RenderSettings.ambientGroundColor;nightHaze=RenderSettings.fogColor;
            nightDensity=RenderSettings.fogDensity;
            if(dawnSky){nightAirTex=dawnSky.mainTexture;dawnSky.mainTexture=dawnAir;}
            if(dawnHome)
            {
                nightHomeEmission=dawnHome.GetColor("_EmissionColor");
                dawnHome.SetColor("_EmissionColor",nightHomeEmission*.12f);
            }
            if(exchangeScreen)
            {
                nightExchangeTex=exchangeScreen.mainTexture;
                nightExchangeEmission=exchangeScreen.GetTexture("_EmissionMap");
                nightExchangeColour=exchangeScreen.GetColor("_EmissionColor");
                nightExchangeLit=exchangeScreen.IsKeywordEnabled("_EMISSION");
            }
            if(marqueeGlass)
            {
                nightMarqueeTex=marqueeGlass.mainTexture;nightTubeGain=marqueeGlass.GetFloat(TubeGain);
                tubeFade=nightTubeGain;
            }
            for(int i=0;i<dawnLamps.Length;i++)
            {
                Light lamp=dawnLamps[i];nightPower[i]=lamp.intensity;
                lamp.intensity*=lamp==benchLamp?.66f:.22f;
            }
            RenderSettings.ambientSkyColor=new Color(.65f,.73f,.81f);
            RenderSettings.ambientEquatorColor=new Color(.49f,.47f,.44f);
            RenderSettings.ambientGroundColor=new Color(.25f,.23f,.21f);
            RenderSettings.fogColor=new Color(.71f,.69f,.66f);RenderSettings.fogDensity=.0095f;
            dawnRoot.gameObject.SetActive(true);
            SetStreetFixtureDay(true);
        }
        dawnBranch=branch;dawnStep=step;
        bool joint=branch==1, delivered=step==2;
        ShowDawnCard(0,joint?dawnRelayPaper:dawnOfficePaper,joint?(step==0?1:0):3);
        ShowDawnCard(1,joint?dawnRelayPaper:dawnOfficePaper,joint?(delivered?3:2):(delivered?2:1));
        ShowDawnCard(2,joint?dawnRelayPaper:dawnOfficePaper,joint?(delivered?3:2):0);
        dawnCards[1].transform.parent.gameObject.SetActive(!joint);
        dawnCards[2].transform.parent.localPosition=joint?new Vector3(17.29f,1.389f,-18.32f):new Vector3(-1.94f,1.258f,-5.415f);
        dawnCards[2].transform.parent.localRotation=Quaternion.Euler(0,joint?0:180,0);
        dawnTicket.gameObject.SetActive(!joint && delivered);
        if(exchangeScreen)
        {
            bool live=joint && delivered;
            exchangeScreen.mainTexture=live?dawnSignal:Texture2D.blackTexture;
            exchangeScreen.SetTexture("_EmissionMap",live?dawnSignal:null);
            exchangeScreen.SetColor("_EmissionColor",live?new Color(.60f,.70f,.59f):Color.black);
            if(live)exchangeScreen.EnableKeyword("_EMISSION");else exchangeScreen.DisableKeyword("_EMISSION");
        }
    }

    void TickDawnTube(float dt)
    {
        if(dawnBranch==0 || !marqueeGlass || tubeFade<=.035f)return;
        tubeFade=Mathf.MoveTowards(tubeFade,.035f,dt*.7f);
        marqueeGlass.SetFloat(TubeGain,tubeFade);
    }

    void LeaveDawn()
    {
        if(dawnBranch==0)return;
        dawnBranch=0;dawnStep=0;
        SetStreetFixtureDay(false);
        if(dawnRoot)dawnRoot.gameObject.SetActive(false);
        RenderSettings.ambientSkyColor=nightSky;RenderSettings.ambientEquatorColor=nightEquator;
        RenderSettings.ambientGroundColor=nightGround;RenderSettings.fogColor=nightHaze;RenderSettings.fogDensity=nightDensity;
        if(dawnSky)dawnSky.mainTexture=nightAirTex;
        if(dawnHome)dawnHome.SetColor("_EmissionColor",nightHomeEmission);
        if(exchangeScreen)
        {
            exchangeScreen.mainTexture=nightExchangeTex;
            exchangeScreen.SetTexture("_EmissionMap",nightExchangeEmission);
            exchangeScreen.SetColor("_EmissionColor",nightExchangeColour);
            if(nightExchangeLit)exchangeScreen.EnableKeyword("_EMISSION");else exchangeScreen.DisableKeyword("_EMISSION");
        }
        if(marqueeGlass){marqueeGlass.mainTexture=nightMarqueeTex;marqueeGlass.SetFloat(TubeGain,nightTubeGain);}
        for(int i=0;i<dawnLamps.Length;i++)if(dawnLamps[i])dawnLamps[i].intensity=nightPower[i];
    }

    void BuildDawnShopfronts()
    {
        dawnPrintBlock=new MaterialPropertyBlock();
        dawnRoot=new GameObject("翌朝の宵待町").transform;dawnRoot.SetParent(transform,false);
        dawnAir=Resources.Load<Texture2D>("KinseiDawn/MorningAir");
        dawnSignal=Resources.Load<Texture2D>("KinseiDawn/MorningSignal");
        dawnRelayPaper=DawnInk("KinseiDawn/RelayPaper");dawnOfficePaper=DawnInk("KinseiDawn/OfficePaper");
        dawnSun=new GameObject("高架越しの朝日").AddComponent<Light>();
        dawnSun.transform.SetParent(dawnRoot,false);dawnSun.type=LightType.Directional;
        dawnSun.transform.rotation=Quaternion.LookRotation(new Vector3(-.829f,-.315f,-.465f));
        dawnSun.color=new Color(1f,.83f,.66f);dawnSun.intensity=1.03f;
        dawnSun.shadows=LightShadows.Hard;dawnSun.shadowStrength=.62f;dawnSun.shadowBias=.04f;
        var lamps=new System.Collections.Generic.List<Light>();
        foreach(var l in GetComponentsInChildren<Light>(true))
            if(l!=dawnSun && (l==benchLamp || System.Array.IndexOf(serviceLights,l)>=0 ||
               l.name=="Street jade neon" || l.name=="Entrance amber" || l.name=="舞台前の歌手用スポット"))lamps.Add(l);
        dawnLamps=lamps.ToArray();nightPower=new float[dawnLamps.Length];

        // On the cafe counter: pigeonholes for requests and a folded drying towel, clear of the siphon.
        var joinery=new NightGeometry();var linen=new NightGeometry();var metal=new NightGeometry();
        Vector3 tray=new Vector3(-15.72f,1.133f,-18.29f);
        joinery.Block(tray,new Vector3(.52f,.028f,.27f));
        for(int i=0;i<3;i++)
            joinery.Block(tray+new Vector3(0,.068f,-.12f+i*.12f),new Vector3(.52f,.12f,.018f));
        for(int i=0;i<7;i++)
            linen.Block(tray+new Vector3(-.17f+i*.055f,.073f+.009f*(i%3),.042f),new Vector3(.115f,.11f,.009f));
        for(int i=0;i<3;i++)
            linen.Block(new Vector3(-15.07f,1.125f+.009f*i,-18.46f+.012f*i),new Vector3(.31f-.011f*i,.010f,.19f));
        // Needle shop: divided brass cash tray and felt-lined receipt pigeonhole.
        Vector3 till=new Vector3(.60f,1.133f,-18.42f);
        metal.Block(till,new Vector3(.43f,.025f,.28f));
        for(int i=0;i<3;i++)metal.Block(till+new Vector3(-.20f+i*.20f,.028f,0),new Vector3(.014f,.05f,.28f));
        for(int i=0;i<2;i++)metal.Block(till+new Vector3(0,.028f,-.135f+i*.27f),new Vector3(.42f,.05f,.014f));
        joinery.Upload(dawnRoot,wood,nightAssets);linen.Upload(dawnRoot,cream,nightAssets);metal.Upload(dawnRoot,brass,nightAssets);

        dawnCards=new Renderer[3];
        dawnCards[0]=DawnNotice("澄子の依頼札",new Vector3(-15.72f,1.372f,-18.52f),.48f,.286f);
        dawnCards[1]=DawnNotice("針音堂の前売り窓口",new Vector3(.65f,1.459f,-18.59f),.65f,.39f);
        dawnCards[2]=DawnNotice("番組または帳場の札",Vector3.zero,.51f,.306f);
        dawnTicket=DawnQuad(dawnRoot,"窓口に届いた一番券",DawnInk("KinseiPrintworks/FirstTicket"));
        dawnTicket.transform.localPosition=new Vector3(.70f,1.149f,-18.42f);
        dawnTicket.transform.localRotation=Quaternion.Euler(90,-8,0);
        dawnTicket.transform.localScale=new Vector3(.087f,.125f,1);
    }

    Material DawnInk(string resource)
    {
        var m=nightAssets.Keep(new Material(Shader.Find("Standard")){name=resource,mainTexture=Resources.Load<Texture2D>(resource)});
        m.SetFloat("_Glossiness",.17f);return m;
    }

    Renderer DawnNotice(string title,Vector3 at,float width,float height)
    {
        var stand=new GameObject(title).transform;stand.SetParent(dawnRoot,false);stand.localPosition=at;
        var rack=new NightGeometry();
        rack.Block(Vector3.zero,new Vector3(width+.024f,height+.024f,.025f));
        rack.Block(new Vector3(0,-height*.67f,-.018f),new Vector3(.064f,height*.34f,.055f));
        rack.Block(new Vector3(0,-height*.84f,-.016f),new Vector3(width*.70f,.023f,.16f));
        rack.Upload(stand,wood,nightAssets);
        var face=DawnQuad(stand,title+"の活版印刷",dawnRelayPaper);
        face.transform.localPosition=Vector3.forward*.014f;
        face.transform.localRotation=Quaternion.Euler(0,180,0);
        face.transform.localScale=new Vector3(width,height,1);
        return face;
    }

    static Renderer DawnQuad(Transform root,string title,Material mat)
    {
        var g=GameObject.CreatePrimitive(PrimitiveType.Quad);g.name=title;g.transform.SetParent(root,false);
        var collider=g.GetComponent<Collider>();collider.enabled=false;Destroy(collider);
        var r=g.GetComponent<Renderer>();r.sharedMaterial=mat;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;return r;
    }
    void ShowDawnCard(int index,Material ink,int tile)
    {
        var r=dawnCards[index];r.sharedMaterial=ink;
        dawnPrintBlock.SetVector(PrintST,new Vector4(.5f,.5f,(tile%2)*.5f,(1-tile/2)*.5f));r.SetPropertyBlock(dawnPrintBlock);
    }
}
