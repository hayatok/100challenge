using UnityEngine;

public sealed partial class KinseiWorld
{
    public static readonly Vector3 BathSpeakerPosition=new(-36.30f,1.27f,-14.22f);
    readonly Transform[] bathCurtains=new Transform[3];
    float curtainTime;
    Font bathFont;
    Material bathCloth;
    Light bathLamp, bathStreetLamp, bathAlleyLamp, bathLobbyLamp;
    Material bathOpal,bathStone,bathGlass;

    public static bool WestBathInView(Vector3 feet)
    {return feet.x< -27 && feet.x> -45 && feet.z> -16.9f && feet.z< -7.1f && feet.y<3;}

    public static Vector3 WestStreetBounds(Vector3 point)
    {
        // Project to the closest accessible rectangle. At a bank corner a small
        // sideways step must not move a pedestrian several metres onto the bridge.
        Vector3 best=BathRect(point,-27.72f,-21.6f,-19.9f,-7.70f);
        Vector3 deck=BathRect(point,-34.03f,-27.72f,-12.56f,-7.84f);
        Vector3 west=BathRect(point,-44.17f,-34.03f,-14.25f,-7.70f);
        Vector3 lobby=BathRect(point,-39.94f,-38.46f,-16.46f,-13.76f);
        if((deck-point).sqrMagnitude<(best-point).sqrMagnitude)best=deck;
        if((west-point).sqrMagnitude<(best-point).sqrMagnitude)best=west;
        if((lobby-point).sqrMagnitude<(best-point).sqrMagnitude)best=lobby;
        Vector3 inside=BathRect(point,-43.09f,-35.30f,-16.45f,-14.88f);
        return (inside-point).sqrMagnitude<(best-point).sqrMagnitude?inside:best;
    }

    static Vector3 BathRect(Vector3 p,float l,float r,float s,float n)
    {return new Vector3(Mathf.Clamp(p.x,l,r),p.y,Mathf.Clamp(p.z,s,n));}
    void BathCollider(string name,Vector3 at,Vector3 size)
    {
        var go=new GameObject(name);go.transform.SetParent(transform,false);
        go.transform.localPosition=at;go.AddComponent<BoxCollider>().size=size;
    }

    void BuildWestBath()
    {
        // The visible stone and asphalt are authored by StreetEnd.West.
        BathCollider("東堤の歩道",new Vector3(-25,-.18f,-13.75f),new Vector3(6.22f,.29f,13.75f));
        BathCollider("運河橋の橋床",new Vector3(-30.85f,-.14f,-10.20f),new Vector3(6.18f,.25f,5.58f));
        BathCollider("西堤の歩道",new Vector3(-39.12f,-.19f,-10.80f),new Vector3(11.09f,.30f,7.53f));
        foreach(float z in new[]{-12.93f,-7.47f})
            BathCollider("石の橋柱と三段手摺",new Vector3(-30.85f,.52f,z),new Vector3(6.2f,1.04f,.20f));
        var fence=new NightGeometry();
        foreach(float x in new[]{-28.07f,-33.61f})
        {
            for(int i=0;i<2;i++)
            {
                float a=i==0?-20.45f:-7.42f, b=i==0?-12.98f:2.76f;
                BathCollider("川沿いの転落止め",new Vector3(x,.49f,(a+b)/2),new Vector3(.13f,.98f,b-a));
                for(float z=a;z<=b;z+=1.45f)fence.Block(new Vector3(x,.48f,z),new Vector3(.076f,.96f,.076f));
                for(int bar=0;bar<2;bar++)fence.Tube(new Vector3(x,.43f+bar*.50f,a),new Vector3(x,.43f+bar*.50f,b),.027f);
            }
        }
        fence.Upload(nightAssets.Root,brass,nightAssets);
        // Low street-edge granite and the house facades mark the accessible block.
        BathCollider("西側街区の石塀",new Vector3(-44.51f,.75f,-10.8f),new Vector3(.24f,1.5f,7.45f));
        BuildBathLane();
        BathCollider("西岸の北縁",new Vector3(-39.1f,.6f,-7.17f),new Vector3(11.0f,1.2f,.19f));
        BathCollider("東岸の北縁",new Vector3(-24.9f,.6f,-7.17f),new Vector3(6.0f,1.2f,.19f));
        BuildBathFront();
        BuildBathLockers();
        BuildBathWayfinder();
    }

    void BuildBathLane()
    {
        var joint=nightAssets.Keep(Mat("土留めの深目地","#484B43",0,.15f,.11f));
        var basalt=nightAssets.Keep(Mat("鉈割りの灰石","#778078",.02f,.23f,.10f));
        var brown=nightAssets.Keep(Mat("濡れ色の古石","#666755",.03f,.25f,.08f));
        var cap=nightAssets.Keep(Mat("笠石の明るい小口","#999785",.03f,.34f,.09f));
        var leaf=nightAssets.Keep(Mat("土留めの蔦","#566246",.01f,.26f,.11f));
        var stems=new NightGeometry();var leaves=new NightGeometry();var drips=new NightGeometry();
        var stone=new NightGeometry();var darker=new NightGeometry();var caps=new NightGeometry();
        // Two garden retaining walls flank a grated lane. Their joint beds start below the road.
        for(int end=0;end<2;end++)
        {
            float start=end==0?-14.55f:-9.94f, length=end==0?2.78f:2.82f;
            int rows=end==0?4:3;
            Box("土留め裏込め",new Vector3(-44.58f,rows*.128f-.065f,start+length*.5f),
                new Vector3(.40f,rows*.256f,length),joint);
            for(int row=0;row<rows;row++)
            {
                float z=start;int index=0;
                while(z<start+length-.008f)
                {
                    float span=Mathf.Min(length-(z-start),row%2==1 && index==0?.31f:.56f+((row*5+index*7)%4)*.08f);
                    var group=(row*7+index)%4==1?darker:stone;
                    group.Block(new Vector3(-44.36f+.009f*((index+row)%3),.057f+row*.256f,z+span*.5f),
                        new Vector3(.105f,.240f,Mathf.Max(.01f,span-.017f)));
                    z+=span;index++;
                }
            }
            for(int j=0;j<4;j++)
                caps.Block(new Vector3(-44.52f,rows*.256f+.002f,start+length*(j+.5f)/4),
                    new Vector3(.53f,.125f,length/4-.014f));
            for(int j=0;j<9;j++)
            {
                float z=start+length*(j+.35f)/9;
                float h=.10f+(j*13%7)*.042f;
                drips.Pane(new Vector3(-44.285f,rows*.256f-.061f-h*.5f,z),Vector3.back*(.007f+.004f*(j%3)),Vector3.up*h*.5f,0);
            }
            for(int j=0;j<5;j++)
            {
                float z=start+.13f+j*.48f;
                float top=rows*.256f;
                for(int k=0;k<5;k++)
                {
                    var a=new Vector3(-44.277f,top-.13f*k,z+Mathf.Sin(k*.75f+j)*.062f);
                    var b=a+new Vector3(.006f,-.137f,Mathf.Cos(k+j)*.051f);
                    stems.Tube(a,b,.008f);
                    leaves.Pane(b,Vector3.back*.041f,Vector3.up*.031f,0);
                }
            }
        }
        stone.Upload(nightAssets.Root,basalt,nightAssets);darker.Upload(nightAssets.Root,brown,nightAssets);
        caps.Upload(nightAssets.Root,cap,nightAssets);stems.Upload(nightAssets.Root,joint,nightAssets);
        leaves.Upload(nightAssets.Root,leaf,nightAssets);drips.Upload(nightAssets.Root,brown,nightAssets);
        // The gate occupies the same boundary as the original stop, with a view through to rear doors.
        var gate=new NightGeometry();
        for(int j=0;j<=12;j++)
            gate.Block(new Vector3(-44.47f,.45f,-11.76f+j*.15f),new Vector3(.043f,.97f,.031f));
        for(int j=0;j<2;j++)
            gate.Block(new Vector3(-44.46f,.25f+j*.61f,-10.86f),new Vector3(.064f,.047f,1.83f));
        gate.Upload(nightAssets.Root,joint,nightAssets);
        Box("小路の突き当たり",new Vector3(-48.81f,1.46f,-10.89f),new Vector3(.25f,3.02f,3.5f),brown);
        Box("勝手口",new Vector3(-48.64f,1.04f,-10.91f),new Vector3(.10f,2.07f,.99f),wood);
        Box("勝手口の型硝子",new Vector3(-48.56f,1.54f,-10.91f),new Vector3(.05f,.73f,.76f),glass);
        var paving=new NightGeometry();var drain=new NightGeometry();
        for(int side=0;side<2;side++)
        {
            float z=side==0?-13.16f:-7.89f;
            for(int j=0;j<18;j++)
                paving.Block(new Vector3(-44.28f+j*.58f,-.017f,z),new Vector3(.565f,.085f,side==0?1.06f:.80f));
            float gz=z+(side==0?.59f:-.48f);
            drain.Block(new Vector3(-39.32f,-.004f,gz),new Vector3(10.40f,.040f,.107f));
            for(int j=0;j<45;j++)
                paving.Block(new Vector3(-44.40f+j*.23f,.019f,gz),new Vector3(.034f,.022f,.108f));
        }
        for(int j=0;j<17;j++)
            paving.Block(new Vector3(-44.67f-j*.25f,-.021f,-10.86f),new Vector3(.237f,.068f,1.80f));
        paving.Upload(nightAssets.Root,basalt,nightAssets);drain.Upload(nightAssets.Root,joint,nightAssets);
        var lampGlass=nightAssets.Keep(Mat("路地灯の磨り硝子","#D5C4A0",.04f,.38f,.55f));
        Box("北側玄関の外灯笠",new Vector3(-35.40f,2.86f,-6.57f),new Vector3(.54f,.10f,.40f),brown);
        Cushion("北側玄関の磨り硝子",new Vector3(-35.40f,2.73f,-6.57f),new Vector3(.35f,.18f,.27f),lampGlass,transform);
        bathStreetLamp=LightAt("北側の庇から路面へ",new Vector3(-35.15f,2.60f,-6.75f),new Color(.73f,.80f,.84f),2.05f,9.25f);
        Cushion("勝手口の路地灯",new Vector3(-48.55f,2.28f,-10.91f),new Vector3(.15f,.23f,.31f),lampGlass,transform);
        bathAlleyLamp=LightAt("勝手口から石塀へ",new Vector3(-46.24f,2.21f,-10.90f),new Color(1,.79f,.57f),1.95f,7.2f);
    }

    void BuildBathWayfinder()
    {
        // A projecting enamel board on the cabaret's last stone bay faces pedestrians
        // leaving Kinsei for Lotus. Its left arrow leads west along the street.
        var centre=new Vector3(-7.86f,2.53f,-9.44f);
        const float yaw=-39;
        var mount=new GameObject("西の湯・袖看板").transform;
        mount.SetParent(transform,false);mount.localPosition=centre;
        mount.localRotation=Quaternion.Euler(0,yaw,0);
        var enamel=nightAssets.Keep(Mat("宵待西浴場の紺琺瑯","#213E43",.22f,.54f,.16f));
        Box("袖看板の巻縁",Vector3.zero,new Vector3(2.21f,.86f,.092f),brass,false,mount);
        Box("紺琺瑯の表示面",Vector3.back*.055f,new Vector3(2.14f,.79f,.036f),enamel,false,mount);
        for(int i=-1;i<=1;i+=2)
        {
            var tip=mount.TransformPoint(new Vector3(i*.71f,.40f,.016f));
            Rail(new Vector3(tip.x,2.98f,-8.26f),tip,.027f,brass);
            Rail(new Vector3(tip.x,3.27f,-8.26f),tip,.015f,brass);
        }
        Text("← 西の湯",mount.TransformPoint(new Vector3(0,.128f,-.079f)),.36f,glow,yaw);
        Text("金星舞台中継",mount.TransformPoint(new Vector3(.13f,-.211f,-.079f)),.205f,cream,yaw);
    }

    Material BathFinish(string name,string texture,string colour,float metal,float gloss)
    {
        var mat=nightAssets.Keep(Mat(name,colour,metal,gloss));
        var grain=Resources.Load<Texture2D>("KinseiWestBath/"+texture);
        if(grain){mat.mainTexture=grain;mat.color=Color.white;}
        return mat;
    }

    void BuildBathFront()
    {
        var tile=BathFinish("薄青磁の釉薬","Tile","#748E81",.16f,.56f);
        var faded=BathFinish("釉薬の窯変","Tile","#899A87",.11f,.43f);
        if(faded.mainTexture)faded.color=new Color(.89f,.91f,.85f);
        var grout=nightAssets.Keep(Mat("目地と洗出し石","#8C8679",.04f,.30f));
        var rubber=nightAssets.Keep(Mat("受像機の黒ゴム","#353832",.02f,.30f));
        var matFinish=BathFinish("履物のゴム敷","Mat","#353832",.02f,.30f);
        var enamel=nightAssets.Keep(Mat("経年した乳白塗装","#A8A08C",.31f,.42f));
        var plumCloth=BathFinish("茄子紺の木綿暖簾","Noren","#592941",0,.25f);
        plumCloth.shader=Resources.Load<Shader>("KinseiBathCloth");
        bathCloth=plumCloth;
        var blueGlass=nightAssets.Keep(Mat("厚手の回収瓶","#AAC9AF",.24f,.85f));
        bathOpal=nightAssets.Keep(Mat("銭湯の乳白硝子","#F1D69F",.07f,.48f,1));
        const float cx=-39.2f;
        var glassShader=Resources.Load<Shader>("KinseiBathGlass");
        bathGlass=glassShader && glassShader.isSupported?nightAssets.Keep(new Material(glassShader){name="脱衣場の網入り型板硝子"}):null;
        if(bathGlass)bathGlass.mainTexture=Resources.Load<Texture2D>("KinseiWestBath/Glass");
        // Outer returns and the rear wall close the existing three-storey house.
        var treads=new NightGeometry();
        var low=new Vector3(cx,.045f,-14.60f);var lowSize=new Vector3(8.7f,.15f,1.68f);
        var high=new Vector3(cx,.14f,-15.62f);var highSize=new Vector3(8.70f,.18f,2.43f);
        treads.Block(low,lowSize,.20f);treads.Block(high,highSize,.20f);
        treads.Upload(nightAssets.Root,bathStone,nightAssets);
        BathCollider("玄関の敷居",low,lowSize);BathCollider("洗出しの上がり框",high,highSize);
        BathCollider("脱衣場との境",new Vector3(cx,1.38f,-16.84f),new Vector3(8.7f,2.76f,.17f));
        Box("奥壁の腰板",new Vector3(cx,.43f,-16.84f),new Vector3(8.7f,.86f,.17f),wood);
        overhead.Add(Box("奥壁・指揮時断面",new Vector3(cx,1.81f,-16.84f),new Vector3(8.7f,1.90f,.17f),wood));
        for(int sign=-1;sign<=1;sign+=2)
            Box("玄関の側壁",new Vector3(cx+sign*4.28f,1.41f,-15.60f),new Vector3(.16f,2.82f,2.45f),tile,true);
        var tilesA=new NightGeometry();var tilesB=new NightGeometry();
        for(int sign=-1;sign<=1;sign+=2)
        {
            float x=cx+sign*2.71f;
            Box("タイル張りの袖壁",new Vector3(x,1.38f,-14.48f),new Vector3(3.28f,2.76f,.19f),grout,true);
            for(int col=0;col<18;col++)
                for(int row=0;row<15;row++)
                {
                    var glaze=(col*7+row*13)%11<2?tilesB:tilesA;
                    glaze.Block(new Vector3(x-1.64f+(col+.5f)*3.28f/18,(row+.5f)*2.76f/15,-14.377f),
                        new Vector3(3.28f/18-.009f,2.76f/15-.010f,.024f));
                }
        }
        tilesA.Upload(nightAssets.Root,tile,nightAssets);tilesB.Upload(nightAssets.Root,faded,nightAssets);
        var eave=Box("銭湯の庇",new Vector3(cx,2.82f,-14.25f),new Vector3(7.15f,.16f,1.68f),wood,false);
        overhead.Add(eave);
        Box("濡れた石の鼻",new Vector3(cx,.108f,-13.78f),new Vector3(7.36f,.024f,.075f),faded);
        Box("玄関マット",new Vector3(cx,.134f,-14.17f),new Vector3(2.30f,.024f,.53f),matFinish);
        for(int j=0;j<17;j++)Box("敷ゴムの曲線溝",new Vector3(cx-1.04f+j*.13f,.149f,-14.17f),
            new Vector3(.013f,.007f,.40f),dark);
        for(int j=0;j<4;j++)
        {
            float x=cx-.79f+j*.52f;
            overhead.Add(Box("奥の建具",new Vector3(x,1.30f,-16.71f),new Vector3(.49f,2.03f,.085f),wood));
            overhead.Add(Box("型硝子",new Vector3(x,1.57f,-16.65f),new Vector3(.416f,1.27f,.036f),bathGlass?bathGlass:glass));
            overhead.Add(Box("木製中桟",new Vector3(x,1.23f,-16.623f),new Vector3(.423f,.036f,.026f),wood));
            if(j==1 || j==2){
                float handX=x+(j==1?.18f:-.18f);
                overhead.Add(Box("角丸引手の縁",new Vector3(handX,1.02f,-16.618f),new Vector3(.045f,.117f,.010f),brass));
                overhead.Add(Box("指の入る引手穴",new Vector3(handX,1.02f,-16.611f),new Vector3(.031f,.091f,.006f),dark));
            }
        }
        // Bandai's window is separate from the receiver. The kiosk has a real sill and muntins.
        Box("番台の木枠",new Vector3(cx-2.06f,1.38f,-14.25f),new Vector3(1.94f,1.53f,.18f),wood);
        Box("番台の曇り硝子",new Vector3(cx-2.06f,1.44f,-14.145f),new Vector3(1.80f,1.24f,.045f),bathGlass?bathGlass:glass);
        for(int j=0;j<3;j++)Box("番台の桟",new Vector3(cx-2.65f+j*.59f,1.44f,-14.115f),new Vector3(.036f,1.26f,.035f),enamel);
        Box("番台の小銭受け",new Vector3(cx-2.06f,.82f,-14.07f),new Vector3(1.94f,.075f,.37f),wood);
        Rail(new Vector3(cx-1.13f,2.43f,-14.29f),new Vector3(cx+1.13f,2.43f,-14.29f),.027f,brass);
        // The command camera looks in from behind the house. The tiled threshold,
        // bench and cashier shelves give the opened section a recognisable floor plan.
        Box("玄関たたきの青磁縁",new Vector3(cx,.238f,-15.74f),new Vector3(2.45f,.015f,1.68f),tile);
        Box("玄関の屋号陶板",new Vector3(cx,.255f,-15.66f),new Vector3(2.10f,.014f,.88f),dark);
        Text("西の湯",new Vector3(cx,.274f,-15.66f),.51f,cream,0);
        transform.GetChild(transform.childCount-1).localRotation=Quaternion.Euler(90,0,0);
        for(int j=0;j<3;j++)
            Box("腰掛けの板",new Vector3(cx+2.58f,.59f,-15.82f+j*.12f),new Vector3(2.0f,.075f,.107f),wood);
        for(int side=-1;side<=1;side+=2)
            Box("腰掛けの脚",new Vector3(cx+2.58f+side*.81f,.405f,-15.70f),new Vector3(.09f,.38f,.36f),dark);
        Box("番台の記帳台",new Vector3(cx-2.52f,.96f,-15.17f),new Vector3(1.75f,.09f,.61f),wood);
        Box("番台の帳面",new Vector3(cx-2.66f,1.021f,-15.17f),new Vector3(.32f,.025f,.22f),cream);
        for(int j=0;j<4;j++)
            Box("番台の小銭皿",new Vector3(cx-2.30f+j*.17f,1.024f,-15.19f),new Vector3(.14f,.028f,.18f),brass);
        BuildNoren(plumCloth);
        BuildBathEquipment(enamel,rubber,blueGlass);
        bathLamp=LightAt("浴場・笠下の反射",new Vector3(cx,2.54f,-13.91f),new Color(1,.81f,.60f),2.16f,6.8f);
        bathLobbyLamp=LightAt("番台の帳場灯",new Vector3(cx-1.55f,2.14f,-16.16f),new Color(.90f,.83f,.69f),1.42f,5.4f);
        SetBathDay(false);
    }
    void BuildNoren(Material cloth)
    {
        const float cx=-39.2f;
        bathFont=Font.CreateDynamicFontFromOSFont(new[]{"Yu Mincho","MS Mincho","Yu Gothic","Meiryo"},148);
        if(bathFont)
        {
            nightAssets.Keep(bathFont);bathFont.RequestCharactersInTexture("ゆ",148);
            RefreshBathLetter(bathFont);Font.textureRebuilt+=RefreshBathLetter;
        }
        float[] widths={.64f,.70f,.64f};
        float left=cx-1.015f;
        for(int panel=0;panel<3;panel++)
        {
            float width=widths[panel];
            var mesh=nightAssets.Keep(new Mesh{name="耳を縫った暖簾のひだ"});
            const int cols=18,rows=6;
            var vertices=new Vector3[(cols+1)*(rows+1)*2];
            var uv=new Vector2[vertices.Length];
            var letter=new Vector2[vertices.Length];
            var triangles=new int[cols*rows*12];
            int t=0;
            for(int face=0;face<2;face++)
            for(int y=0;y<=rows;y++)
            for(int x=0;x<=cols;x++)
            {
                int n=face*(cols+1)*(rows+1)+y*(cols+1)+x;
                float u=x/(float)cols,v=y/(float)rows;
                float ripple=Mathf.Cos((u*width*3.2f+panel*.33f)*Mathf.PI*2);
                vertices[n]=new Vector3((u-.5f)*width,-v*(.85f+panel*.007f)+v*.014f*ripple,
                    .019f*ripple*(.4f+v*.6f)-face*.004f);
                uv[n]=new Vector2(u*width,1-v);
                letter[n]=new Vector2(.5f-(left+u*width-cx)/1.09f,(.91f-v)/.84f);
                if(x==0 || y==0)continue;
                int a=n-cols-2,b=n-cols-1,c=n-1;
                if(face==0){triangles[t++]=a;triangles[t++]=c;triangles[t++]=b;triangles[t++]=b;triangles[t++]=c;triangles[t++]=n;}
                else {triangles[t++]=a;triangles[t++]=b;triangles[t++]=c;triangles[t++]=b;triangles[t++]=n;triangles[t++]=c;}
            }
            mesh.vertices=vertices;mesh.uv=uv;mesh.uv2=letter;mesh.triangles=triangles;mesh.RecalculateNormals();mesh.RecalculateTangents();
            var curtain=Surface("風を受ける暖簾",mesh,cloth,transform,false).transform;
            curtain.localPosition=new Vector3(left+width*.5f,2.42f,-14.25f);bathCurtains[panel]=curtain;
            left+=width+.024f;
        }
    }

    void RefreshBathLetter(Font font)
    {
        if(font!=bathFont || !bathCloth || !font.GetCharacterInfo('ゆ',out var glyph,148))return;
        bathCloth.SetTexture("_Glyph",font.material.mainTexture);
        bathCloth.SetVector("_GlyphBL",glyph.uvBottomLeft);bathCloth.SetVector("_GlyphBR",glyph.uvBottomRight);
        bathCloth.SetVector("_GlyphTL",glyph.uvTopLeft);
    }

    void BuildBathEquipment(Material enamel,Material rubber,Material blueGlass)
    {
        var centre=new Vector3(-37.35f,1.58f,-14.29f);
        Cushion("浴場用の奥行きのある受像機",centre,new Vector3(1.02f,.82f,.57f),wood,transform);
        BathCollider("木箱と張り出した管面",centre+Vector3.forward*.07f,new Vector3(1.02f,.82f,.72f));
        Cushion("受像機の鉱物色ベゼル",centre+Vector3.forward*.28f,new Vector3(.96f,.74f,.095f),enamel,transform);
        Cushion("管のゴム押さえ",centre+new Vector3(-.041f,.035f,.34f),new Vector3(.78f,.60f,.09f),rubber,transform);
        var tube=Surface("湯客の金星中継",tubeGlass,marqueeGlass,transform);
        tube.transform.localPosition=centre+new Vector3(-.041f,.035f,.389f);
        tube.transform.localRotation=Quaternion.Euler(0,180,0);
        tube.transform.localScale=Vector3.one*1.25f;
        for(int k=0;k<2;k++)
            Cylinder("選局つまみ",centre+new Vector3(.39f,.065f-.15f*k,.345f),.046f,.055f,dark).transform.rotation=Quaternion.Euler(90,0,0);
        Box("牛乳箱の底",new Vector3(-42.11f,.20f,-13.97f),new Vector3(.67f,.11f,.47f),wood,true);
        for(int s=-1;s<=1;s+=2)
        {
            for(int j=0;j<2;j++)
                Box("通い箱の板",new Vector3(-42.11f,.27f+j*.115f,-13.97f+s*.225f),new Vector3(.67f,.083f,.034f),wood);
            Box("牛乳箱の木口",new Vector3(-42.11f+s*.316f,.335f,-13.97f),new Vector3(.041f,.25f,.46f),wood);
        }
        for(int k=0;k<6;k++)
        {
            float x=-42.33f+k%3*.211f,z=-14.074f+k/3*.18f;
            Cylinder("牛乳回収瓶",new Vector3(x,.364f,z),.062f,.23f,blueGlass);
            Part("丸い瓶肩",PrimitiveType.Sphere,new Vector3(x,.47f,z),new Vector3(.123f,.102f,.123f),blueGlass);
            Cylinder("牛乳瓶の首",new Vector3(x,.532f,z),.034f,.084f,blueGlass);
            Cylinder("厚い瓶口",new Vector3(x,.574f,z),.042f,.024f,blueGlass);
            Cylinder("瓶口の内側",new Vector3(x,.587f,z),.026f,.002f,dark);
        }
        var grille=BathSpeakerPosition;
        BathCollider("外付けスピーカーの箱",grille+Vector3.forward*.035f,new Vector3(.39f,.39f,.19f));
        Cylinder("鋳物スピーカー",grille,.193f,.13f,enamel).transform.localRotation=Quaternion.Euler(90,0,0);
        Cylinder("スピーカーの振動板",grille+Vector3.forward*.075f,.151f,.02f,rubber).transform.localRotation=Quaternion.Euler(90,0,0);
        for(int i=-4;i<=4;i++)
        {
            float y=i*.029f,w=2*Mathf.Sqrt(.145f*.145f-y*y);
            Box("拡声器の横桟",grille+new Vector3(0,y,.093f),new Vector3(w,.012f,.018f),enamel);
        }
        Box("浴場の行燈枠",grille+new Vector3(0,.58f,.025f),new Vector3(.38f,.42f,.14f),brass);
        Cushion("浴場の行燈",grille+new Vector3(0,.58f,.104f),new Vector3(.31f,.34f,.06f),bathOpal,transform);
        Rail(grille+new Vector3(.27f,0,0),grille+new Vector3(.27f,1.24f,0),.022f,brass);
        Rail(grille+new Vector3(.27f,1.24f,0),grille+new Vector3(-.80f,1.24f,0),.022f,brass);
        Cylinder("天井灯の引掛け座",new Vector3(-39.2f,2.68f,-13.81f),.18f,.11f,brass);
        Part("乳白の軒灯",PrimitiveType.Sphere,new Vector3(-39.2f,2.57f,-13.81f),new Vector3(.36f,.25f,.36f),bathOpal);
        for(int r=0;r<3;r++)Cylinder("乳白灯のリブ",new Vector3(-39.2f,2.49f+r*.04f,-13.81f),.15f+r*.009f,.016f,bathOpal);
    }

    void TickBathCurtain(float dt,Vector3 audience)
    {
        if(!bathCurtains[0] || !WestBathInView(audience))return;
        curtainTime+=dt;
        for(int j=0;j<bathCurtains.Length;j++)
        {
            var curtain=bathCurtains[j];
            float brush=Mathf.Clamp01(1-Vector2.Distance(new Vector2(audience.x,audience.z),new Vector2(curtain.position.x,curtain.position.z))/.75f);
            float ripple=Mathf.Sin(curtainTime*1.8f+j*.72f)*2.7f+Mathf.Sin(curtainTime*.77f)*1.4f;
            float pitch=ripple+brush*17*(audience.z>curtain.position.z?1:-1);
            curtain.localRotation=Quaternion.RotateTowards(curtain.localRotation,Quaternion.Euler(pitch,0,ripple*.22f),dt*50);
        }
    }

    void SetBathDay(bool day)
    {
        if(bathGlass)bathGlass.SetFloat("_Lamp",day?.30f:.82f);
        if(bathLamp)bathLamp.enabled=!day;
        if(bathStreetLamp)bathStreetLamp.enabled=!day;
        if(bathAlleyLamp)bathAlleyLamp.enabled=!day;
        if(bathLobbyLamp)bathLobbyLamp.enabled=!day;
        if(bathOpal)bathOpal.SetColor("_EmissionColor",day?Color.black:new Color(1,.76f,.43f));
    }
}
