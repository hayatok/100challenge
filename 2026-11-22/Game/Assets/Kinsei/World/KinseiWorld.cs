using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Showa-future supper club. Dimensions are metres; all furniture is modeled at human scale.</summary>
public sealed partial class KinseiWorld : MonoBehaviour
{
    Material brass, plum, wood, dark, cream, velvet, glow, cyan, glass, mirrorMat;
    Material boards, amberBoards, asphalt;
    Transform ashtray;
    Transform mirrorHinge;
    Transform upperReceiver;
    Light hallTubeLight, boothTubeLight;
    Light tacticalFill;
    public Vector3 UpperScreenCentre => upperReceiver.TransformPoint(new Vector3(-.065f,.248f,-.203f));
    public Transform MirrorReceiver => mirrorHinge;
    bool built;
    Font signFont;
    Material signInk;
    readonly System.Collections.Generic.List<Renderer> fixedRenderers = new System.Collections.Generic.List<Renderer>();
    readonly System.Collections.Generic.List<GameObject> overhead = new System.Collections.Generic.List<GameObject>();
    public void Construct()
    {
        if (built) return;
        built = true;
        brass=Mat("Aged champagne brass", "#B68C4B", .78f,.72f);
        plum=Mat("Aubergine leather", "#351E39",.05f,.46f);
        var upholstery=Resources.Load<Texture2D>("Art/kinsei-oxblood-vinyl");if(upholstery){plum.mainTexture=upholstery;plum.color=new Color(.66f,.51f,.63f);}
        wood=Mat("Smoked walnut veneer", "#B6A294",.05f,.44f);
        Finish(wood,"smoked_walnut_veneer",new Vector2(2,1),.48f);
        boards=Mat("Waxed parquet", "#A99186",.045f,.56f);
        Finish(boards,"herringbone_parquet",Vector2.one,.42f);
        amberBoards=new Material(boards){name="Honey parquet",color=new Color(.86f,.69f,.50f)};
        asphalt=Mat("Rain-dark street", "#827C78",.08f,.52f);
        Finish(asphalt,"worn_asphalt",new Vector2(8,3),.66f);
        dark=Mat("Blue black lacquer", "#121E27",.2f,.65f);
        cream=Mat("Ivory plaster", "#C2AF8D",0,.22f);
        velvet=Mat("Wine velvet", "#5B1831",0,.12f);
        Finish(velvet,"velour_velvet",new Vector2(2,4),.37f);
        glow=Mat("Warm opal lamp", "#FFE0A0",0,.4f,2.1f);
        cyan=Mat("Jade neon", "#42DCCB",0,.5f,2.2f);
        glass=Mat("Smoked glazing", "#235F64",.5f,.93f);
        mirrorMat=Mat("Articulated silver mirror", "#9EBAB4",.92f,.96f);
        signFont=Font.CreateDynamicFontFromOSFont(new[]{"Yu Mincho","MS Mincho","Yu Gothic","Meiryo"},80);
        if(signFont) {
            signInk=new Material(Resources.Load<Shader>("KinseiSignType"));
            signInk.mainTexture=signFont.material.mainTexture;
            Font.textureRebuilt+=RefreshTypeface;
        }
        welt=Mat("Corded oxblood welting","#6E4440",.18f,.48f);
        Shell(); Floor(); Stage(); Furniture(); Balcony(); Entry(); BuildDistrict(); Mirror(); Lighting();
        BuildNightscape();
        BuildFrontage();
        BuildHallServiceDoor();
        BuildMarquee();
        BuildWestBath();
        BatchArchitecture();
        ReleaseVeneerSources();
    }
    Material Mat(string name,string hex,float metal,float gloss,float emission=0)
    {
        ColorUtility.TryParseHtmlString(hex,out Color c);
        var m=new Material(Shader.Find("Standard")){name=name,color=c};
        m.enableInstancing=true;
        m.SetFloat("_Metallic",metal);m.SetFloat("_Glossiness",gloss);
        if(emission>0){m.EnableKeyword("_EMISSION");m.SetColor("_EmissionColor",c*emission);}
        return m;
    }
    void Finish(Material material,string scan,Vector2 tiles,float relief)
    {
        material.mainTexture=Resources.Load<Texture2D>("KinseiSurfaces/"+scan+"_Diffuse");
        material.mainTextureScale=tiles;
        material.SetTexture("_BumpMap",Resources.Load<Texture2D>("KinseiSurfaces/"+scan+"_nor_gl"));
        material.SetFloat("_BumpScale",relief);material.EnableKeyword("_NORMALMAP");
    }
    GameObject Part(string n,PrimitiveType type,Vector3 p,Vector3 s,Material m,bool solid=false,Transform parent=null)
    {
        var o=GameObject.CreatePrimitive(type);o.name=n;o.transform.SetParent(parent?parent:transform,false);
        o.transform.localPosition=p;o.transform.localScale=s;o.GetComponent<Renderer>().sharedMaterial=m;
        if(!solid) Destroy(o.GetComponent<Collider>());
        o.isStatic=parent==null || parent!=mirrorHinge;
        if(parent==null || parent!=mirrorHinge) fixedRenderers.Add(o.GetComponent<Renderer>());
        if(n.StartsWith("Ceiling") || n=="Canopy" || n.StartsWith("Canopy luminous") || n=="Booth canopy") overhead.Add(o);
        return o;
    }
    GameObject Box(string n,Vector3 p,Vector3 s,Material m,bool solid=false,Transform parent=null)=>Part(n,PrimitiveType.Cube,p,s,m,solid,parent);
    GameObject Cylinder(string n,Vector3 p,float radius,float height,Material m,bool solid=false,Transform parent=null)=>Part(n,PrimitiveType.Cylinder,p,new Vector3(radius*2,height*.5f,radius*2),m,solid,parent);
    void Rail(Vector3 a,Vector3 b,float radius,Material m,Transform parent=null)
    {var o=Cylinder("Brass rail",(a+b)*.5f,radius,Vector3.Distance(a,b),m,false,parent);o.transform.localRotation=Quaternion.FromToRotation(Vector3.up,b-a);}
    void Shell()
    {
        Box("Club foundation",new Vector3(0,-.15f,.5f),new Vector3(18,.3f,17),dark,true);
        BuildBackstage();
        VeneerBox("East wall",new Vector3(9,3,.5f),new Vector3(.25f,6,17),wood,true,upright:true);
        VeneerBox("Rear wall",new Vector3(0,3,9),new Vector3(18,6,.25f),wood,true,upright:true);
        Box("Ceiling",new Vector3(0,6.2f,.5f),new Vector3(18,.25f,17),dark);
        for(int side=-1;side<=1;side+=2)
        {
            for(int i=0;i<9;i++)
            {
                float z=-7+i*1.8f;
                if(side<0 && z<2.75f && z+1.6f>.75f)continue;
                Box("Fluted wall pilaster",new Vector3(side*8.77f,2.6f,z),new Vector3(.16f,5.2f,.10f),brass);
                Box("Wall upholstered panel",new Vector3(side*8.8f,1.4f,z+.8f),new Vector3(.12f,2.4f,1.45f),plum);
            }
            Box("Continuous picture rail",new Vector3(side*8.69f,3.25f,.5f),new Vector3(.1f,.09f,17),brass);
            if(side>0)Box("Skirting",new Vector3(side*8.69f,.13f,.5f),new Vector3(.1f,.26f,17),brass);
        }
        for(float x=-7.5f;x<=7.5f;x+=3)
        {Box("Ceiling coffer",new Vector3(x,6,.5f),new Vector3(.12f,.15f,17),brass);}
        for(float z=-6;z<=9;z+=3)Box("Ceiling coffer cross",new Vector3(0,6,z),new Vector3(18,.15f,.12f),brass);
    }
    void Floor()
    {
        for(int x=0;x<18;x++)for(int z=0;z<17;z++)
        {var p=Box("Walnut parquet",new Vector3(x-8.5f,.008f,z-7.5f),new Vector3(.997f,.018f,.997f),boards);p.transform.Rotate(0,(x+z)%2*90,0);}
        Cylinder("Dance floor brass perimeter",new Vector3(0,.022f,-1.1f),3.65f,.025f,brass);
        // A genuine radial mesh gives the dance floor a starburst inlay instead of square tiles.
        for(int i=0;i<48;i++)
        {
            float a=i*Mathf.PI*2/48,b=(i+1)*Mathf.PI*2/48;
            var mesh=new Mesh();mesh.vertices=new[]{new Vector3(0,.041f,-1.1f),new Vector3(Mathf.Sin(a)*3.58f,.041f,Mathf.Cos(a)*3.58f-1.1f),new Vector3(Mathf.Sin(b)*3.58f,.041f,Mathf.Cos(b)*3.58f-1.1f)};
            mesh.uv=new[]{new Vector2(.5f,0),new Vector2(0,2),new Vector2(1,2)};
            mesh.triangles=new[]{0,1,2};mesh.RecalculateNormals();mesh.RecalculateTangents();
            var go=new GameObject("Radial parquet inlay");go.transform.SetParent(transform,false);go.AddComponent<MeshFilter>().sharedMesh=mesh;
            var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=i%2==0?wood:amberBoards;fixedRenderers.Add(renderer);
        }
        Cylinder("Starburst central medallion",new Vector3(0,.05f,-1.1f),.55f,.025f,brass);
        Cylinder("Central walnut inset",new Vector3(0,.066f,-1.1f),.49f,.02f,wood);
    }
    void Stage()
    {
        VeneerBox("Raised cabaret stage",new Vector3(-5,.24f,4.4f),new Vector3(6,.48f,3.6f),wood,true);
        Box("Stage brass apron",new Vector3(-5,.25f,2.59f),new Vector3(6,.4f,.05f),brass);
        VeneerBox("Stage first step",new Vector3(-5,.08f,2.1f),new Vector3(2.6f,.16f,.6f),wood,true);
        for(int i=0;i<31;i++)Cylinder("Gathered velvet curtain",new Vector3(-8+i*.2f,2.7f,6.05f),.15f,4.5f,velvet);
        BuildStageSign();
        StageBand();
        Box("Stage lip moulding",new Vector3(-5,.48f,2.565f),new Vector3(6,.04f,.065f),brass);
        for(int side=-1;side<=1;side+=2)Box("Stage brass upright",new Vector3(-5+side*3.15f,2.5f,5.7f),new Vector3(.15f,5,.25f),brass);
        var microphone=Instantiate(Resources.Load<GameObject>("KinseiMicrophone/KinseiRibbon"),transform,false);
        microphone.name="金星のリボンマイク";
        microphone.transform.localPosition=new Vector3(-5,.48f,3.4f);
        Material plating=Resources.Load<Material>("KinseiMicrophone/RibbonMetal");
        foreach(var part in microphone.GetComponentsInChildren<MeshRenderer>())
        {
            // The little audience-side enamel badge resolves the FBX importer's change of handedness.
            if(part.name.StartsWith("14 ") && Vector3.Dot(part.bounds.center-microphone.transform.position,transform.forward)>0)
                microphone.transform.Rotate(0,180,0,Space.World);
            part.sharedMaterial=plating;
            fixedRenderers.Add(part);
        }
        BuildBroadcastDesk();
    }
    void Sofa(Vector3 p,float yaw,float width=2.5f)
    {
        var root=new GameObject("Channel tufted banquette").transform;root.SetParent(transform,false);root.localPosition=p;root.localRotation=Quaternion.Euler(0,yaw,0);
        Box("Recessed walnut plinth",new Vector3(0,.15f,.015f),new Vector3(width-.16f,.27f,.72f),wood,true,root);
        Cushion("Banquette seat piping",new Vector3(0,.393f,-.045f),new Vector3(width-.10f,.23f,.85f),welt,root);
        Cushion("Loose leather cushion",new Vector3(0,.432f,-.05f),new Vector3(width-.12f,.25f,.84f),plum,root,true);
        int channels=Mathf.RoundToInt(width/.23f);
        float pitch=(width-.20f)/channels;
        for(int i=0;i<channels;i++)
        {
            float x=(i+.5f-channels*.5f)*pitch;
            float curve=Mathf.Pow(2*x/width,2);
            var roll=Cushion("Fluted leather back",new Vector3(x,.89f,.325f-.21f*curve),new Vector3(pitch+.025f,.82f-.12f*curve,.30f),plum,root);
            roll.transform.localRotation=Quaternion.Euler(8,-x/width*29,0);
        }
        Box("Back support",new Vector3(0,.87f,.36f),new Vector3(width-.22f,.77f,.18f),wood,true,root);
        for(int side=-1;side<=1;side+=2)
        {
            float x=side*(width/2-.105f);
            Cushion("Arm welt",new Vector3(x,.64f,-.045f),new Vector3(.225f,.355f,.88f),welt,root);
            Cushion("Rolled armrest",new Vector3(x,.67f,-.045f),new Vector3(.235f,.345f,.88f),plum,root,true);
        }
    }
    void Table(Vector3 p,float r=.48f)
    {
        Cylinder("Cocktail table foot",p+Vector3.up*.05f,.28f,.1f,dark);
        Cylinder("Fluted brass pedestal",p+Vector3.up*.38f,.055f,.66f,brass);
        Cylinder("Black marble cocktail table",p+Vector3.up*.74f,r,.07f,dark,true);
        Cylinder("Table brass edge",p+Vector3.up*.725f,r+.015f,.025f,brass);
        Cylinder("Opal table lamp base",p+new Vector3(.12f,.79f,.1f),.09f,.035f,brass);
        Cylinder("Lamp stem",p+new Vector3(.12f,.9f,.1f),.016f,.22f,brass);
        Part("Opal globe",PrimitiveType.Sphere,p+new Vector3(.12f,1.05f,.1f),new Vector3(.2f,.24f,.2f),glow);
        for(int i=0;i<2;i++){var g=p+new Vector3(-.16f+i*.28f,.84f,-.15f);Cylinder("Champagne stem",g,.008f,.13f,brass);Cylinder("Champagne coupe",g+Vector3.up*.08f,.065f,.045f,glass);}
    }
    void Furniture()
    {
        for(int side=-1;side<=1;side+=2)for(int i=0;i<3;i++)
        {float z=-5.5f+i*2.7f;Sofa(new Vector3(side*7.4f,0,z),side*90);Table(new Vector3(side*6.3f,0,z));}
        // Service bar sits along the east wall, safely beyond the stair approach.
        VeneerBox("Back bar",new Vector3(7.9f,.56f,7.5f),new Vector3(1.2f,1.12f,2.5f),wood,true,upright:true);
        Box("Bar marble counter",new Vector3(7.9f,1.15f,7.5f),new Vector3(1.4f,.12f,2.7f),dark);
    }
    void Balcony()
    {
        VeneerBox("Upper conversation terrace",new Vector3(0,3.05f,7.45f),new Vector3(18,.3f,3.1f),wood,true);
        // Sixteen risers with 20 cm height: directly traversable by the player's step controller.
        for(int i=0;i<16;i++)
        {float h=(i+1)*.2f;VeneerBox("Right stair tread "+i,new Vector3(6,h*.5f,.15f+i*.36f),new Vector3(1.9f,h,.37f),wood,true);Box("Stair brass nosing",new Vector3(6,h+.008f,-.025f+i*.36f),new Vector3(1.9f,.018f,.025f),brass);}
        for(int side=-1;side<=1;side+=2)
        {float x=6+side*1.0f;Rail(new Vector3(x,1.05f,0),new Vector3(x,4.2f,5.8f),.035f,brass);for(int i=0;i<9;i++){float z=i*.7f;Rail(new Vector3(x,z/5.8f*3.2f,z),new Vector3(x,1.05f+z/5.8f*3.2f,z),.018f,brass);}}
        // Terrace rail leaves the 1.9m stair opening unobstructed.
        Rail(new Vector3(-8.7f,4.23f,5.87f),new Vector3(4.95f,4.23f,5.87f),.035f,brass);
        for(float x=-8.7f;x<=4.95f;x+=.65f)Rail(new Vector3(x,3.2f,5.87f),new Vector3(x,4.23f,5.87f),.018f,brass);
        Sofa(new Vector3(-1.14f,3.2f,7.4f),-90,2.2f);Sofa(new Vector3(1.14f,3.2f,7.4f),90,2.2f);
        Table(new Vector3(0,3.2f,7.4f),.70f);
        ashtray=new GameObject("辰が脇へよけるガラス灰皿").transform;
        ashtray.SetParent(transform,false);ashtray.position=new Vector3(-.62f,3.99f,7.22f);
        AshtrayPart(Vector3.zero,.095f,.027f,glass);
        AshtrayPart(Vector3.up*.016f,.074f,.009f,dark);
        for(int i=0;i<12;i++){
            float a=i*Mathf.PI/6;AshtrayPart(new Vector3(.084f*Mathf.Cos(a),.020f,.084f*Mathf.Sin(a)),.012f,.026f,glass);
        }
        BackBar();
        Box("Booth canopy",new Vector3(0,5.55f,7.5f),new Vector3(5.2f,.14f,2.65f),brass);
        for(int i=0;i<12;i++)Box("Rear fan brass rib",new Vector3(-2.5f+i*.45f,4.4f,8.81f),new Vector3(.025f,2.4f,.035f),brass);
    }
    void Entry()
    {
        Box("Street asphalt",new Vector3(0,-.13f,-12),new Vector3(30,.2f,8),asphalt,true);
        for(int s=-1;s<=1;s+=2)
        {
            var barrier=new GameObject("Facade stone wing");
            barrier.transform.SetParent(transform,false);
            barrier.transform.localPosition=new Vector3(s*5.4f,2.7f,-8);
            barrier.AddComponent<BoxCollider>().size=new Vector3(7.2f,5.4f,.4f);
            Box("Street curb",new Vector3(s*7.5f,.09f,-10),new Vector3(3,.18f,3.8f),dark,true);
        }
        for(int s=-1;s<=1;s+=2){Cylinder("Revolving entry jamb",new Vector3(s*1.65f,1.85f,-8),.08f,3.7f,brass,true);}
        // Glazed pivot wings are held open beside the centre walking path.
        Cylinder("Entry crown",new Vector3(0,3.65f,-8),1.65f,.1f,brass);
        var poster=Resources.Load<Texture2D>("Art/kinsei-poster");
        if(poster){var pm=new Material(Shader.Find("Unlit/Texture"));pm.mainTexture=poster;var q=Part("Kinsei street poster",PrimitiveType.Quad,new Vector3(-5.5f,2.2f,-7.97f),new Vector3(2,2,1),pm);q.transform.rotation=Quaternion.identity;}
        Text("KINSEI",new Vector3(0,4.65f,-8.51f),.65f,cream,0);
        Text("キャバレー  金星",new Vector3(0,4.05f,-8.51f),.19f,glow,0);
        Box("Vertical neon sign",new Vector3(8.5f,4.8f,-8.6f),new Vector3(.8f,2.5f,.25f),dark);
        Text("K\nI\nN\nS\nE\nI",new Vector3(8.5f,4.8f,-8.77f),.29f,cyan,0);
    }
    void Text(string text,Vector3 p,float size,Material mat,float yaw)
    {
        var go=new GameObject("Architectural lettering "+text);go.transform.SetParent(transform,false);go.transform.localPosition=p;go.transform.rotation=Quaternion.Euler(0,yaw,0);
        var t=go.AddComponent<TextMesh>();t.text=text;t.fontSize=64;t.characterSize=size/6.4f;t.anchor=TextAnchor.MiddleCenter;t.alignment=TextAlignment.Center;t.color=mat.color;
        if(signFont){t.font=signFont;go.GetComponent<MeshRenderer>().sharedMaterial=signInk;}
    }
    void RefreshTypeface(Font font) { if(font==signFont && signInk)signInk.mainTexture=font.material.mainTexture; }
    void OnDestroy() {LeaveDawn();Font.textureRebuilt-=RefreshTypeface;Font.textureRebuilt-=RefreshBathLetter;if(signInk)Destroy(signInk);if(terraceImage){terraceImage.Release();Destroy(terraceImage);}nightAssets?.Release();ReleaseMarquee();ReleaseStageSign();}
    void Mirror()
    {
        Table(new Vector3(-3,0,0),.55f);
        var pivot=new GameObject("Articulated mirror hinge");mirrorHinge=pivot.transform;mirrorHinge.SetParent(transform,false);mirrorHinge.localPosition=new Vector3(-3,1.05f,0);
        Cylinder("Mirror pedestal",new Vector3(-3,.95f,0),.035f,.34f,brass);
        terraceScreen=new Material(mirrorMat){name="Terrace receiver glass"};
        Receiver(mirrorHinge,mirrorMat);
        hallTubeLight=TubeLight(mirrorHinge);
        var upper=new GameObject("梶の卓上受像機").transform;upper.SetParent(transform,false);
        upper.localPosition=new Vector3(.15f,4.02f,7.84f);upper.localRotation=Quaternion.Euler(0,-65,0);
        upper.localScale=Vector3.one*.82f;Receiver(upper,terraceScreen);
        upperReceiver=upper;boothTubeLight=TubeLight(upper);
        SetMirror(0,null);
    }

    Light TubeLight(Transform receiver)
    {
        var bulb=new GameObject("ブラウン管からの照り返し");
        bulb.transform.SetParent(receiver,false);
        bulb.transform.localPosition=new Vector3(-.065f,.285f,-.245f);
        var spill=bulb.AddComponent<Light>();
        spill.type=LightType.Spot;spill.spotAngle=112;spill.innerSpotAngle=73;
        spill.color=new Color(.76f,.88f,1f);spill.range=2.5f;
        spill.shadows=LightShadows.None;spill.renderMode=LightRenderMode.ForcePixel;
        spill.enabled=false;return spill;
    }

    static void LightCaller(Light light,Vector3? eyes,float progress)
    {
        light.enabled=eyes.HasValue;
        if(!eyes.HasValue)return;
        light.transform.LookAt(eyes.Value);
        light.intensity=Mathf.Lerp(.24f,1.22f,Mathf.SmoothStep(0,1,progress*5));
    }

    public void SetMirror(float progress,Texture feed,Vector3? returnEyes=null,Vector3? callerEyes=null)
    {
        if(!built)Construct();
        mirrorHinge.localRotation=Quaternion.Euler(Mathf.Lerp(5,-18,Mathf.Clamp01(progress)),Mathf.Lerp(0,18,Mathf.Clamp01(progress)),0);
        LightCaller(hallTubeLight,callerEyes,progress);LightCaller(boothTubeLight,returnEyes,progress);
        if(feed && SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Null && Time.unscaledTime>=nextTerraceFrame)
        {
            if(!terraceCamera) PrepareTerraceCamera();
            if(returnEyes.HasValue)terraceCamera.transform.LookAt(returnEyes.Value-Vector3.up*.045f);
            terraceCamera.Render();
            nextTerraceFrame=Time.unscaledTime+.10f;
        }
        ShowPicture(mirrorMat,feed && terraceImage ? (Texture)terraceImage : standby);
        ShowPicture(terraceScreen,feed ? feed : standby);
    }
    void BatchArchitecture()
    {
        // Combine by material while retaining the original collision geometry. Roof pieces stay separate for mode switching.
        var groups=new System.Collections.Generic.Dictionary<Material,System.Collections.Generic.List<CombineInstance>>();
        foreach(var renderer in fixedRenderers)
        {
            if(!renderer)continue;
            // A canopy's meshes can be children of its cutaway root. Baking them
            // into the permanent batch defeats SetTactical even when that root hides.
            bool cutaway=false;
            for(Transform ancestor=renderer.transform;ancestor!=null && ancestor!=transform;ancestor=ancestor.parent)
                if(overhead.Contains(ancestor.gameObject)){cutaway=true;break;}
            if(cutaway)continue;
            var filter=renderer.GetComponent<MeshFilter>();if(!filter || !filter.sharedMesh)continue;
            Material material=renderer.sharedMaterial;if(!groups.ContainsKey(material))groups[material]=new System.Collections.Generic.List<CombineInstance>();
            groups[material].Add(new CombineInstance{mesh=filter.sharedMesh,transform=transform.worldToLocalMatrix*filter.transform.localToWorldMatrix});renderer.enabled=false;
        }
        foreach(var group in groups){var go=new GameObject("Batched architecture / "+group.Key.name);go.transform.SetParent(transform,false);var mesh=new Mesh{indexFormat=IndexFormat.UInt32};mesh.CombineMeshes(group.Value.ToArray(),true,true);go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterial=group.Key;}
    }
    public void SetTactical(bool enabled)
    {
        foreach(var o in overhead)if(o)o.SetActive(!enabled);
        if(enabled && !tacticalFill){
            var go=new GameObject("Command map / shadowless floor fill");go.transform.SetParent(transform,false);
            go.transform.localRotation=Quaternion.Euler(72,-25,0);
            tacticalFill=go.AddComponent<Light>();tacticalFill.type=LightType.Directional;
            tacticalFill.color=new Color(.82f,.90f,1f);tacticalFill.intensity=.72f;
            tacticalFill.shadows=LightShadows.None;
        }
        if(tacticalFill)tacticalFill.enabled=enabled;
    }
    void AshtrayPart(Vector3 at,float radius,float height,Material material)
    {
        var piece=GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        piece.name="切子";piece.transform.SetParent(ashtray,false);piece.transform.localPosition=at;
        piece.transform.localScale=new Vector3(radius*2,height*.5f,radius*2);
        piece.GetComponent<Renderer>().sharedMaterial=material;
        var c=piece.GetComponent<Collider>();c.enabled=false;Destroy(c);
    }
    public Vector3 SetAshtray(float progress)
    {
        ashtray.position=new Vector3(-.62f,3.99f,Mathf.Lerp(7.22f,7.42f,Mathf.SmoothStep(0,1,progress)));
        return ashtray.position+Vector3.up*.025f;
    }
    Light LightAt(string name,Vector3 p,Color color,float power,float range)
    {var go=new GameObject(name);go.transform.SetParent(transform,false);go.transform.localPosition=p;var l=go.AddComponent<Light>();l.type=LightType.Point;l.color=color;l.intensity=power;l.range=range;l.shadows=LightShadows.None;return l;}
    void Lighting()
    {
        RenderSettings.ambientMode=AmbientMode.Trilight;RenderSettings.ambientSkyColor=new Color(.24f,.29f,.36f);RenderSettings.ambientEquatorColor=new Color(.21f,.17f,.21f);RenderSettings.ambientGroundColor=new Color(.11f,.07f,.06f);
        RenderSettings.fog=true;RenderSettings.fogMode=FogMode.ExponentialSquared;RenderSettings.fogColor=new Color(.045f,.055f,.075f);RenderSettings.fogDensity=.012f;
        foreach(float z in new[]{-5f,-.5f,2.2f})
        {
            Chandelier(z);
            LightAt("Chandelier amber bounce",new Vector3(0,4.88f,z),new Color(1,.87f,.72f),.94f,8.1f);
        }
        LightAt("Stage rose wash",new Vector3(-5,3.9f,3),new Color(1,.60f,.46f),1.32f,6.1f);
        var booth=LightAt("Upper private booth",new Vector3(-1.85f,5.3f,6.1f),new Color(1,.84f,.68f),2.10f,6);
        booth.type=LightType.Spot;booth.spotAngle=97;booth.transform.LookAt(new Vector3(.05f,3.96f,7.4f));
        booth.shadows=LightShadows.Soft;booth.shadowStrength=.64f;booth.shadowNormalBias=.16f;booth.shadowBias=.035f;
        LightAt("Terrace cool glass fill",new Vector3(2.65f,4.6f,7.95f),new Color(.55f,.73f,.91f),.59f,3.5f);
        // Low resolution realtime probe is rendered once after construction, not every frame.
        var probeGo=new GameObject("Club reflection probe");probeGo.transform.SetParent(transform,false);probeGo.transform.localPosition=new Vector3(0,2,0);
        var probe=probeGo.AddComponent<ReflectionProbe>();probe.mode=ReflectionProbeMode.Realtime;probe.refreshMode=ReflectionProbeRefreshMode.OnAwake;probe.timeSlicingMode=ReflectionProbeTimeSlicingMode.AllFacesAtOnce;probe.resolution=128;probe.size=new Vector3(18,8,22);probe.boxProjection=true;probe.intensity=.65f;
    }
}




