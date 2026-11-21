using UnityEngine;

// Each address is measured from its front door. Positive local z faces the street.
public sealed partial class KinseiWorld
{
    readonly Transform[] shopDoors = new Transform[3];
    readonly Light[] serviceLights = new Light[3];
    Light benchLamp;
    readonly Renderer[] shopBulbs = new Renderer[3];
    readonly bool[] shopTrading = { true, true, true };
    readonly Transform[] rotatingDiscs = new Transform[2];
    static readonly string[] ShopNames = { "純喫茶 ロータス", "貸レコード 針音堂", "共同送像所" };
    public static readonly Vector3 CoffeeCupCentre=new Vector3(-16.94f,1.176f,-18.63f);
    public static readonly Vector3 RadioTrimSocket=new Vector3(15.08f,1.235f,-18.62f);

    void BuildDistrict()
    {
        BuildRailway();
        for (int side = -1; side <= 1; side += 2)
            Box("Surface street extension", new Vector3(18.5f * side,-.13f,-12), new Vector3(7,.2f,8), asphalt,true);
        Box("Rear lane",new Vector3(0,-.13f,-18.5f),new Vector3(44,.2f,5),asphalt,true);
        var mint = Mat("Oxidised cafe enamel","#52796A",.34f,.48f);
        var charcoal = Mat("Black vulcanite","#282322",.06f,.27f);
        var oxblood = Mat("Record shop oxblood","#743C38",.23f,.41f);
        var duck = Mat("Telephone exchange enamel","#455C68",.43f,.38f);
        var plaster=Mat("Painted shop plaster","#D4C7AD",.02f,.18f);
        Finish(plaster,"beige_wall_002",new Vector2(3.3f,1.25f),.55f);
        var accents = new[] {mint,oxblood,duck};
        for(int shop=0;shop<3;shop++)
        {
            float x=(shop-1)*16;
            var room=new GameObject(ShopNames[shop]).transform;
            room.SetParent(transform,false);
            room.localPosition=new Vector3(x,0,-14);
            var accent=accents[shop];
            Box("Raised shop floor",new Vector3(0,.01f,-3),new Vector3(9.2f,.10f,6),shop==0?boards:amberBoards,true,room);
            Box("Rear plaster",new Vector3(0,1.72f,-6),new Vector3(9.2f,3.44f,.16f),plaster,true,room);
            for(int s=-1;s<=1;s+=2)
            {
                // Alley entrance on either end leaves a second route out at closing.
                Box("Side wall",new Vector3(s*4.6f,1.72f,-3.87f),new Vector3(.16f,3.44f,4.26f),wood,true,room);
                Box("Side entry post",new Vector3(s*4.6f,1.72f,-.17f),new Vector3(.16f,3.44f,.34f),wood,true,room);
                Box("Side lintel",new Vector3(s*4.6f,2.95f,-1),new Vector3(.16f,.98f,1.55f),accent,true,room);
                Box("Display stall",new Vector3(s*2.78f,.48f,0),new Vector3(3.64f,.96f,.19f),accent,true,room);
                Box("Display sill",new Vector3(s*2.78f,1,0),new Vector3(3.69f,.09f,.33f),brass,false,room);
                for(int j=0;j<3;j++)
                    Box("Shopfront mullion",new Vector3(s*(.98f+1.78f*j),1.78f,0),new Vector3(.07f,1.55f,.12f),brass,false,room);
                Box("Raised fascia",new Vector3(s*2.8f,2.94f,0),new Vector3(3.6f,.85f,.19f),accent,true,room);
            }
            Box("Enamel name board",new Vector3(0,2.99f,.13f),new Vector3(7.4f,.72f,.14f),accent,false,room);
            Text(ShopNames[shop],new Vector3(x,3,-13.77f),.41f,glow,180);
            Box("Ceiling shop eave",new Vector3(0,3.48f,-2.63f),new Vector3(9.46f,.17f,6.94f),dark,false,room);
            var door=new GameObject("Shop sliding leaf").transform;
            door.SetParent(room,false);
            shopDoors[shop]=door;
            Moving(Box("Reeded sliding panel",new Vector3(0,1.22f,.04f),new Vector3(1.91f,2.4f,.10f),glass,true,door));
            Moving(Box("Leaf kickplate",new Vector3(0,.27f,.11f),new Vector3(1.86f,.47f,.04f),accent,false,door));
            Moving(Box("Sliding handle",new Vector3(.73f,1.1f,.15f),new Vector3(.043f,.33f,.085f),brass,false,door));
            door.localPosition=Vector3.right*1.99f;

            var lamp=new GameObject("Counter light").AddComponent<Light>();
            lamp.transform.SetParent(room,false);
            lamp.transform.localPosition=new Vector3(-1.5f,3.11f,-1.5f);
            lamp.transform.LookAt(room.TransformPoint(new Vector3(0,1.18f,-4.4f)));
            lamp.type=LightType.Spot;lamp.spotAngle=108;lamp.range=8;lamp.intensity=2.05f;
            lamp.shadowBias=.035f;lamp.shadowNormalBias=.14f;lamp.shadowStrength=.60f;
            lamp.color=shop==2?new Color(.75f,.88f,1):new Color(1,.87f,.72f);
            serviceLights[shop]=lamp;
            var bulb=Cylinder("Opal service lamp",new Vector3(0,2.65f,-3.8f),.24f,.17f,glow,false,room);
            Moving(bulb);
            shopBulbs[shop]=bulb.GetComponent<Renderer>();
            Cylinder("Pressed metal shade",new Vector3(0,2.78f,-3.8f),.32f,.10f,accent,false,room);
            Box("Counter plinth",new Vector3(0,.55f,-4.25f),new Vector3(4.45f,.98f,.78f),wood,true,room);
            Box("Counter worktop",new Vector3(0,1.07f,-4.25f),new Vector3(4.66f,.10f,.94f),accent,true,room);
            Box("Worn counter nosing",new Vector3(0,1.065f,-3.766f),new Vector3(4.57f,.037f,.03f),brass,false,room);
            if(shop==0) DressCafe(room,mint);
            else if(shop==1) DressRecordShop(room,charcoal);
            else DressExchange(room,duck,charcoal);
        }
    }

    void Moving(GameObject part)
    {
        part.isStatic=false;
        fixedRenderers.Remove(part.GetComponent<Renderer>());
    }

    Material exchangeScreen;
    Texture exchangeStandby;

    public void SetExchangePicture(Texture picture)
    {
        if(exchangeScreen)exchangeScreen.mainTexture=picture?picture:exchangeStandby;
    }

    Material ShopPrint(Transform room,string resource,Vector3 at,float width,float height,float pitch=0)
    {
        var tex=Resources.Load<Texture2D>(resource);
        if(!tex)return null;
        var ink=new Material(Shader.Find("Standard")){mainTexture=tex};
        ink.SetFloat("_Glossiness",.22f);
        var frame=new GameObject(resource).transform;
        frame.SetParent(room,false);frame.localPosition=at;frame.localRotation=Quaternion.Euler(pitch,180,0);
        Box("Printed matter backing",Vector3.zero,new Vector3(width+.022f,height+.022f,.022f),brass,false,frame);
        Part("Printed face",PrimitiveType.Quad,new Vector3(0,0,-.013f),new Vector3(width,height,1),ink,false,frame);
        return ink;
    }

    void DressCafe(Transform room,Material enamel)
    {
        ShopPrint(room,"KinseiAtelier/lotus-sign",new Vector3(-2.9f,1.71f,-5.89f),2.2f,.75f);
        ShopPrint(room,"KinseiDistrictArt/lotus-float",new Vector3(-2.75f,1.8f,.12f),.92f,1.227f);
        ShopPrint(room,"KinseiDistrictArt/lotus-voucher",new Vector3(.65f,1.145f,-4.08f),.29f,.145f,90);
        CafeService(room);
        for(int i=0;i<2;i++)
        {
            float x=i==0?-3.78f:3.78f;
            Cylinder("Marble cafe table",new Vector3(x,.78f,-3.15f),.49f,.07f,cream,true,room);
            Cylinder("Pedestal foot",new Vector3(x,.39f,-3.15f),.095f,.73f,brass,true,room);
            Cushion("Cafe banquette",new Vector3(x,.38f,-4.15f),new Vector3(.96f,.62f,.62f),enamel,room,true);
            Cushion("Banquette upholstered back",new Vector3(x,.82f,-4.44f),new Vector3(.96f,.60f,.14f),plum,room,true);
            Cylinder("Coffee cup",new Vector3(x,.878f,-3.15f),.05f,.105f,cream,false,room);
            Cylinder("Coffee surface",new Vector3(x,.932f,-3.15f),.044f,.003f,dark,false,room);
        }
    }

    void DressRecordShop(Transform room,Material rubber)
    {
        DressRecordWall(room);
        ShopPrint(room,"KinseiDistrictArt/needle-sleeve",new Vector3(-2.6f,1.79f,.12f),.90f,.90f);
        ShopPrint(room,"KinseiDistrictArt/needle-return",new Vector3(.05f,1.144f,-4.08f),.32f,.16f,90);
        for(int i=0;i<2;i++)
        {
            float x=i==0?-1.34f:1.34f;
            Box("Turntable plinth",new Vector3(x,1.19f,-4.30f),new Vector3(.62f,.14f,.50f),dark,false,room);
            var disc=Cylinder("Playing record",new Vector3(x-.05f,1.28f,-4.29f),.19f,.025f,rubber,false,room);
            Cylinder("Paper disc label",new Vector3(x-.05f,1.296f,-4.29f),.061f,.006f,cream,false,room);
            var mark=Box("Label title",new Vector3(x-.05f,1.301f,-4.255f),new Vector3(.053f,.004f,.007f),dark,false,room);
            Moving(mark);var spindle=new GameObject("Rotating label").transform;spindle.SetParent(room,false);
            spindle.localPosition=disc.transform.localPosition;mark.transform.SetParent(spindle,true);rotatingDiscs[i]=spindle;
            Rail(new Vector3(x+.23f,1.32f,-4.46f),new Vector3(x+.07f,1.31f,-4.25f),.012f,brass,room);
        }
        for(int s=-1;s<=1;s+=2)
        {
            Box("Browser record bin",new Vector3(s*3.64f,.59f,-3.1f),new Vector3(1.15f,.95f,1.6f),wood,true,room);
            for(int column=0;column<2;column++)for(int i=0;i<11;i++){
                Vector3 at=new Vector3(s*3.64f+(column-.5f)*.40f,1.14f,-3.75f+i*.12f);
                var cover=Box("Used record sleeve",at,new Vector3(.315f,.315f,.010f),cream,false,room).transform;
                cover.localRotation=Quaternion.Euler(-9,0,0);
                PrintedFace(room,"Rental LP",sleevePrints[(i+column*3+(s+1))%8],at+cover.localRotation*Vector3.forward*.006f,
                    new Vector2(.314f,.314f),cover.localRotation*Quaternion.Euler(0,180,0));
            }
        }
    }

    void DressExchange(Transform room,Material enamel,Material rubber)
    {
        DressExchangePrints(room);
        Vector3 trim=room.InverseTransformPoint(RadioTrimSocket);
        Cushion("送像卓の利得調整器",trim-Vector3.up*.064f,new Vector3(.18f,.12f,.16f),enamel,room);
        Cylinder("調整穴の金具",trim-Vector3.up*.003f,.019f,.006f,brass,false,room);
        Cylinder("調整ねじ",trim,.009f,.003f,rubber,false,room);
        var lampFoot=new Vector3(-.60f,1.14f,-4.54f);
        var lampElbow=lampFoot+new Vector3(.12f,.39f,-.06f);
        var lampHead=lampElbow+new Vector3(-.19f,.23f,.03f);
        Cylinder("調整灯の台",lampFoot,.085f,.022f,enamel,false,room);
        Rail(lampFoot,lampElbow,.012f,brass,room);Rail(lampElbow,lampHead,.012f,brass,room);
        var shade=Part("調整灯の琺瑯笠",PrimitiveType.Sphere,lampHead,new Vector3(.163f,.078f,.13f),enamel,false,room);
        shade.transform.localRotation=Quaternion.Euler(0,0,-25);
        var lit=Part("調整灯の乳白ガラス",PrimitiveType.Sphere,lampHead+new Vector3(-.014f,-.029f,0),new Vector3(.129f,.03f,.112f),glow,false,room);
        lit.transform.localRotation=shade.transform.localRotation;
        benchLamp=new GameObject("村瀬の仕事灯").AddComponent<Light>();
        benchLamp.transform.SetParent(room,false);benchLamp.transform.localPosition=lampHead+new Vector3(-.03f,-.06f,0);
        benchLamp.transform.LookAt(room.TransformPoint(trim+new Vector3(-.06f,.14f,-.15f)));
        benchLamp.type=LightType.Spot;benchLamp.spotAngle=108;benchLamp.innerSpotAngle=62;benchLamp.range=1.80f;
        benchLamp.color=new Color(1f,.93f,.80f);benchLamp.intensity=1.65f;benchLamp.shadows=LightShadows.None;
        exchangeScreen=ShopPrint(room,"KinseiDistrictArt/relay-test",new Vector3(-1.12f,1.56f,-4.16f),.70f,.525f);
        if(exchangeScreen)exchangeStandby=exchangeScreen.mainTexture;
        Box("Bench receiver",new Vector3(-1.12f,1.56f,-4.40f),new Vector3(.85f,.68f,.44f),enamel,false,room);
        Cushion("Exchange transcription deck",new Vector3(-1.95f,1.196f,-4.22f),new Vector3(.44f,.11f,.41f),wood,room);
        Cylinder("Exchange platter",new Vector3(-1.95f,1.253f,-4.22f),.158f,.014f,rubber,false,room);
        Rail(new Vector3(-1.77f,1.29f,-4.38f),new Vector3(-1.89f,1.28f,-4.24f),.008f,brass,room);
        ShopPrint(room,"KinseiDistrictArt/relay-card",new Vector3(.56f,1.145f,-4.11f),.35f,.219f,90);
        for(int s=-1;s<=1;s+=2)
        {
            float x=s*3.78f;
            Box("Relay equipment cabinet",new Vector3(x,1.16f,-5.37f),new Vector3(1.16f,2.2f,.83f),enamel,true,room);
            for(int row=0;row<4;row++)
            {
                float y=.51f+row*.47f;
                Box("Chassis panel",new Vector3(x,y,-4.937f),new Vector3(1.03f,.37f,.035f),dark,false,room);
                for(int key=0;key<5;key++)
                    Box("Bakelite selector",new Vector3(x-.37f+key*.17f,y,-4.90f),new Vector3(.078f,.105f,.06f),key==2?cream:rubber,false,room);
            }
        }
    }

    public void SetDistrictOpen(int shop,bool open)
    {
        if(shop<0 || shop>=shopTrading.Length || !shopDoors[shop])return;
        shopTrading[shop]=open;
        serviceLights[shop].enabled=open;
        if(shop==2 && benchLamp)benchLamp.enabled=open;
        shopBulbs[shop].sharedMaterial=open?glow:cream;
    }

    public void TickShops(float dt,Vector3 audience)
    {
        if(!shopDoors[0])return;
        if(masterDisc && masterDisc.activeSelf)masterDisc.transform.Rotate(0,dt*200f,0,Space.Self);
        for(int i=0;i<shopDoors.Length;i++)
        {
            var door=shopDoors[i];
            serviceLights[i].shadows=audience.z< -12.8f && Mathf.Abs(audience.x-(i-1)*16)<5?
                LightShadows.Soft:LightShadows.None;
            float target=shopTrading[i]?1.99f:0;
            if(door.localPosition.x!=target)
                door.localPosition=Vector3.right*Mathf.MoveTowards(door.localPosition.x,target,dt*2.5f);
        }
        if(shopTrading[1])foreach(var disc in rotatingDiscs)
            disc.Rotate(0,dt*200f,0,Space.Self);
    }
}
