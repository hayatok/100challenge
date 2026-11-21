using UnityEngine;

public sealed partial class KinseiWorld
{
    Transform backstageLeaf;
    GameObject backstagePass;
    Light backstageSpill;
    public Vector3 BackstageHandle => backstageLeaf.TransformPoint(new Vector3(-.15f,1.09f,-.56f));
    public Vector3 PassSlot => new Vector3(-9.26f,1.07f,-.05f);

    void BuildBackstage()
    {
        // The west wall runs from -8 to +9. Its opening is clear from .75 to 2.75.
        VeneerBox("West wall south",new Vector3(-9,3,-3.625f),new Vector3(.25f,6,8.75f),wood,true,upright:true);
        VeneerBox("West wall north",new Vector3(-9,3,5.875f),new Vector3(.25f,6,6.25f),wood,true,upright:true);
        VeneerBox("West wall header",new Vector3(-9,4.17f,1.75f),new Vector3(.25f,3.66f,2),wood,true,upright:true);
        Box("Passage paving",new Vector3(-10.6f,-.13f,-2.52f),new Vector3(3.2f,.24f,11.16f),asphalt,true);
        var plaster=Mat("西通路の洗い出し壁", "#A69A86",.03f,.30f);
        Finish(plaster,"beige_wall_002",new Vector2(5,1.4f),.62f);
        Box("Passage boundary",new Vector3(-12.14f,1.72f,-2.52f),new Vector3(.16f,3.44f,11.16f),plaster,true);
        Box("Passage return",new Vector3(-10.6f,1.72f,3.05f),new Vector3(3.2f,3.44f,.16f),plaster,true);
        Box("Brass backstage blade",new Vector3(-10.6f,2.92f,-7.95f),new Vector3(2.8f,.57f,.14f),dark);
        Text("金星　楽屋口",new Vector3(-10.6f,2.92f,-8.035f),.32f,glow,0);
        Box("Sliding track",new Vector3(-9.20f,2.32f,.74f),new Vector3(.18f,.10f,4.12f),brass);
        Box("Ticket window",PassSlot+Vector3.up*.10f,new Vector3(.11f,.46f,.54f),dark);
        Box("Pass exchange shelf",PassSlot,new Vector3(.28f,.045f,.64f),brass);
        Box("Tour portrait frame",new Vector3(-9.175f,1.60f,-2.43f),new Vector3(.08f,.76f,.58f),brass);
        BackstagePrint("Portrait",new Vector3(-9.22f,1.60f,-2.43f),.48f,.66f,cream);
        BackstagePrint("WardrobeCard",new Vector3(-9.22f,1.14f,-2.43f),.24f,.15f,cream);
        backstagePass=BackstagePrint("Pass",PassSlot+new Vector3(-.075f,.12f,0),.21f,.12f,cyan);
        Moving(backstagePass);backstagePass.SetActive(false);
        backstageLeaf=new GameObject("楽屋の防音引戸").transform;
        backstageLeaf.SetParent(transform,false);
        Moving(Box("Padded sliding leaf",new Vector3(0,1.14f,0),new Vector3(.13f,2.28f,2.03f),plum,true,backstageLeaf));
        BackstagePrint("DoorLeather",new Vector3(-.068f,1.14f,0),1.82f,2.18f,plum,backstageLeaf);
        Moving(Box("Kick plate",new Vector3(-.081f,.18f,0),new Vector3(.026f,.25f,1.85f),brass,false,backstageLeaf));
        for(int s=-1;s<=1;s+=2) {
            Moving(Box("Pull mounting",new Vector3(-.11f,1.09f+s*.16f,-.56f),new Vector3(.10f,.045f,.07f),brass,false,backstageLeaf));
            var wheel=Cylinder("Track roller",new Vector3(-.04f,2.29f,s*.71f),.077f,.09f,dark,false,backstageLeaf);
            wheel.transform.localRotation=Quaternion.Euler(0,0,90);Moving(wheel);
        }
        for(int i=0;i<10;i++) {
            Vector3 a=GripPoint(i/10f), b=GripPoint((i+1)/10f);
            var grip=Cylinder("引手の磨いた丸棒",(a+b)*.5f,.019f,(b-a).magnitude+.001f,brass,false,backstageLeaf);
            grip.transform.localRotation=Quaternion.FromToRotation(Vector3.up,b-a);Moving(grip);
        }
        DressBackstagePassage(plaster);
        backstageSpill=LightAt("Light through dressing door",new Vector3(-9.39f,1.86f,1.75f),new Color(1,.68f,.34f),.45f,4);
        var porch=LightAt("札口の手許灯",new Vector3(-11.37f,2.64f,.68f),new Color(1,.82f,.63f),3.4f,4.8f);
        porch.type=LightType.Spot;porch.spotAngle=77;porch.innerSpotAngle=44;
        porch.transform.LookAt(transform.TransformPoint(new Vector3(-9.10f,1.21f,.63f)));
        SetBackstageDoor(0);
    }

    static Vector3 GripPoint(float t) => new(-.109f-.042f*Mathf.Sin(Mathf.PI*t),.93f+.32f*t,-.56f);

    void DressBackstagePassage(Material plaster)
    {
        var enamel=Mat("楽屋通路の緑釉", "#3F5B50", .06f,.54f);
        var deepEnamel=Mat("補修で入った濃い緑釉", "#354D44",.04f,.47f);
        for(int tone=0;tone<2;tone++) {
            var vertices=new System.Collections.Generic.List<Vector3>();
            var triangles=new System.Collections.Generic.List<int>();
            for(int row=0;row<34;row++) for(int col=0;col<10;col++) {
                if(((row*11+col*7)%13<2?1:0)!=tone) continue;
                float x=-12.036f+col*.308f,z=-8.04f+row*.32f;
                int first=vertices.Count;
                for(int ring=0;ring<2;ring++) {
                    float lip=ring==0?0:.004f, y=ring==0?-.009f:.0015f;
                    vertices.Add(new Vector3(x+lip,y,z+lip));vertices.Add(new Vector3(x+lip,y,z+.315f-lip));
                    vertices.Add(new Vector3(x+.303f-lip,y,z+.315f-lip));vertices.Add(new Vector3(x+.303f-lip,y,z+lip));
                }
                for(int side=0;side<4;side++) {
                    int a=first+side,b=first+(side+1)%4;
                    triangles.AddRange(new[]{a,b,b+4,a,b+4,a+4});
                }
                triangles.AddRange(new[]{first+4,first+5,first+6,first+4,first+6,first+7});
            }
            var mesh=new Mesh{name="雨の通路・目地と面取り"};mesh.SetVertices(vertices);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();
            Surface(mesh.name,mesh,tone==0?enamel:deepEnamel,transform);
        }
        Box("真鍮の排水枠",new Vector3(-10.45f,.006f,-7.54f),new Vector3(.76f,.012f,.22f),brass);
        Box("排水口の影",new Vector3(-10.45f,.015f,-7.54f),new Vector3(.72f,.012f,.185f),dark);
        for(int i=0;i<15;i++)Box("排水口の桟",new Vector3(-10.79f+i*.048f,.026f,-7.54f),new Vector3(.015f,.014f,.18f),brass);
        for(int i=0;i<2;i++) {
            float z=i==0?-5.7f:-1.75f;
            Rail(new Vector3(-9.17f,2.78f,z),new Vector3(-9.48f,2.78f,z),.026f,dark);
            Rail(new Vector3(-9.48f,2.78f,z),new Vector3(-9.48f,2.58f,z),.026f,dark);
            Cylinder("庇の琺瑯シェード",new Vector3(-9.48f,2.56f,z),.151f,.065f,enamel);
            Cushion("乳白のランプ",new Vector3(-9.48f,2.49f,z),new Vector3(.19f,.14f,.19f),glow,transform);
            LightAt("楽屋の常夜灯",new Vector3(-9.55f,2.39f,z),new Color(1,.76f,.49f),1.65f,4.7f);
        }
        Rail(new Vector3(-9.16f,2.82f,-7.8f),new Vector3(-9.16f,2.82f,1.03f),.016f,dark);
        Box("衣裳写真の上の水切り",new Vector3(-9.27f,2.04f,-2.43f),new Vector3(.26f,.034f,.69f),brass);
        var zinc=Mat("雨樋の亜鉛", "#687374",.53f,.39f);
        Rail(new Vector3(-11.98f,.23f,-2.16f),new Vector3(-11.98f,3.44f,-2.16f),.054f,zinc);
        Rail(new Vector3(-11.98f,.23f,-2.16f),new Vector3(-11.85f,.13f,-2.16f),.053f,zinc);
        for(int tie=0;tie<3;tie++)Cylinder("雨樋の帯金",new Vector3(-11.98f,.6f+tie*1.15f,-2.16f),.060f,.042f,dark);
        var windows=Resources.Load<Texture2D>("KinseiNightscape/UpperGlass");
        for(int i=0;i<3;i++) {
            float z=-6.44f+i*3.52f;
            var pane=Mat("西通路の型板ガラス "+i, "#BCC0AA",.09f,.33f);
            var offset=new Vector2((i%2)*.5f+.007f,(1-i/2)*.5f+.007f);
            pane.mainTexture=windows;pane.mainTextureScale=new Vector2(.485f,.485f);pane.mainTextureOffset=offset;
            pane.EnableKeyword("_EMISSION");pane.SetTexture("_EmissionMap",windows);
            pane.SetTextureScale("_EmissionMap",pane.mainTextureScale);pane.SetTextureOffset("_EmissionMap",offset);
            pane.SetColor("_EmissionColor",new Color(.53f,.48f,.39f));
            Box("台所窓の木枠",new Vector3(-12.012f,2.04f,z),new Vector3(.105f,1.15f,1.42f),wood);
            var light=Part("台所の型板ガラス",PrimitiveType.Quad,new Vector3(-11.952f,2.04f,z),new Vector3(1.31f,1.04f,1),pane);
            light.transform.localRotation=Quaternion.Euler(0,-90,0);
            Box("台所窓の中央框",new Vector3(-11.932f,2.04f,z),new Vector3(.046f,1.07f,.036f),wood);
            Box("モルタルの窓台",new Vector3(-11.95f,1.43f,z),new Vector3(.27f,.08f,1.54f),plaster);
            Box("窓上の水切り",new Vector3(-11.90f,2.67f,z),new Vector3(.38f,.046f,1.56f),zinc);
        }
    }

    GameObject BackstagePrint(string key,Vector3 position,float width,float height,Material fallback,Transform parent=null)
    {
        var paper=fallback;
        var tex=Resources.Load<Texture2D>("KinseiBackstage/"+key);
        if(tex) {
            paper=new Material(Shader.Find("Standard")){name=key,mainTexture=tex};
            paper.SetFloat("_Glossiness",key=="DoorLeather"?.36f:key=="Portrait"?.42f:.17f);
        }
        var panel=Part(key,PrimitiveType.Quad,position,new Vector3(width,height,1),paper,false,parent);
        panel.transform.localRotation=Quaternion.Euler(0,90,0);
        if(parent)Moving(panel);
        return panel;
    }

    public void ShowBackstagePass(bool shown) => backstagePass.SetActive(shown);
    public void SetBackstageDoor(float travel)
    {
        backstageLeaf.localPosition=new Vector3(-9.05f,0,1.75f-2.09f*travel);
        backstageSpill.intensity=.18f+1.5f*travel;
    }
}
