using UnityEngine;

public sealed partial class KinseiWorld
{
    Mesh TurnedProfile(string label,params Vector2[] rings)
    {
        const int sides=48;
        int row=sides+1;
        var vertices=new Vector3[rings.Length*row];var uv=new Vector2[vertices.Length];
        var indices=new int[(rings.Length-1)*sides*6];int next=0;
        for(int j=0;j<rings.Length;j++)for(int i=0;i<=sides;i++) {
            float u=(float)i/sides, angle=u*2*Mathf.PI;
            vertices[j*row+i]=new Vector3(rings[j].x*Mathf.Cos(angle),rings[j].y,rings[j].x*Mathf.Sin(angle));
            uv[j*row+i]=new Vector2(u,(float)j/(rings.Length-1));
            if(i==sides || j==rings.Length-1)continue;
            int v=j*row+i;indices[next++]=v;indices[next++]=v+row;indices[next++]=v+1;
            indices[next++]=v+1;indices[next++]=v+row;indices[next++]=v+row+1;
        }
        var mesh=new Mesh{name=label,vertices=vertices,uv=uv,triangles=indices};
        mesh.RecalculateNormals();mesh.RecalculateTangents();return mesh;
    }
    void CafeService(Transform room)
    {
        var bottleGlass=new Material(Resources.Load<Shader>("KinseiBorosilicate"));
        var tile=Mat("Iron-green ceramic glaze","#5A9883",.09f,.61f);
        Finish(tile,"interior_tiles",new Vector2(5.2f,.85f),.72f);
        var blackCoffee=Mat("Dark coffee","#31180F",.04f,.80f);
        var porcelain=Mat("Cream hotel porcelain","#E2D7BB",.03f,.75f);
        var blacksteel=Mat("Oxidized stove metal","#474749",.64f,.42f);
        Box("Hand-set glazed splashback",new Vector3(0,1.46f,-5.90f),new Vector3(9.04f,1.06f,.036f),tile,false,room);
        Box("Brass tile trim",new Vector3(0,2.008f,-5.87f),new Vector3(9.05f,.026f,.035f),brass,false,room);
        for(int tier=0;tier<2;tier++){
            float y=1.73f+tier*.36f;
            Box("Dried walnut cup shelf",new Vector3(1.82f,y,-5.73f),new Vector3(3.06f,.041f,.34f),wood,false,room);
            for(int support=0;support<2;support++)
                Rail(new Vector3(.54f+support*2.55f,y-.16f,-5.86f),new Vector3(.54f+support*2.55f,y-.03f,-5.60f),.012f,brass,room);
        }
        var cup=TurnedProfile("Tapered cafe cup",new(.007f,.005f),new(.032f,.005f),new(.038f,.014f),new(.051f,.068f),new(.052f,.077f),new(.047f,.079f),new(.042f,.065f),new(.029f,.018f),new(.007f,.017f));
        var dish=TurnedProfile("Saucer with rolled edge",new(.001f,0),new(.044f,0),new(.079f,.006f),new(.086f,.013f),new(.079f,.014f),new(.041f,.006f),new(.001f,.006f));
        var workCup=room.InverseTransformPoint(CoffeeCupCentre);
        Surface("澄子の取り分け用カップ",cup,porcelain,room).transform.localPosition=workCup-Vector3.up*.050f;
        Surface("仕事台の受皿",dish,porcelain,room).transform.localPosition=workCup-Vector3.up*.057f;
        Cylinder("カップに注いだコーヒー",workCup+Vector3.up*.009f,.042f,.002f,blackCoffee,false,room);
        for(int i=0;i<11;i++){
            int tier=i/6;float x=.60f+(i%6)*.43f,y=1.76f+tier*.36f,z=-5.68f;
            var saucer=Surface("Stacked saucer",dish,porcelain,room);saucer.transform.localPosition=new Vector3(x,y,z);
            var mug=Surface("Gold rim cup",cup,porcelain,room);mug.transform.localPosition=new Vector3(x,y+.008f,z);
            for(int s=0;s<8;s++){
                float a=Mathf.Lerp(-1.28f,1.28f,s/8f),b=Mathf.Lerp(-1.28f,1.28f,(s+1)/8f);
                Vector3 centre=new Vector3(x+.042f,y+.055f,z);
                Rail(centre+new Vector3(.029f*Mathf.Cos(a),.025f*Mathf.Sin(a),0),centre+new Vector3(.029f*Mathf.Cos(b),.025f*Mathf.Sin(b),0),.005f,porcelain,room);
            }
        }
        var globe=TurnedProfile("Handblown siphon flask",new(.026f,0),new(.067f,.01f),new(.105f,.043f),new(.12f,.084f),new(.115f,.126f),new(.086f,.161f),new(.036f,.19f),new(.031f,.215f));
        var hopper=TurnedProfile("Vacuum coffee funnel",new(.012f,0),new(.013f,.13f),new(.053f,.15f),new(.083f,.173f),new(.087f,.19f),new(.086f,.34f),new(.091f,.35f),new(.085f,.354f));
        var brew=TurnedProfile("Brew below the meniscus",new(.018f,0),new(.066f,.01f),new(.102f,.041f),new(.115f,.080f),new(.111f,.115f),new(.001f,.116f));
        for(int i=0;i<2;i++){
            float x=-1.84f+i*.65f,z=-4.40f;
            Cylinder("Copper stove base",new Vector3(x,1.155f,z),.132f,.045f,blacksteel,false,room);
            Cylinder("Alcohol burner",new Vector3(x,1.196f,z),.074f,.046f,brass,false,room);
            var baseAt=new Vector3(x,1.246f,z);
            Surface("Lower glass flask",globe,bottleGlass,room).transform.localPosition=baseAt;
            Surface("Morning coffee",brew,blackCoffee,room).transform.localPosition=baseAt+Vector3.up*.002f;
            Surface("Filter chamber",hopper,bottleGlass,room).transform.localPosition=baseAt+Vector3.up*.105f;
            Cylinder("Gauze filter seam",baseAt+Vector3.up*.28f,.076f,.012f,porcelain,false,room);
            Rail(new Vector3(x+.143f,1.17f,z),new Vector3(x+.143f,1.461f,z),.012f,blacksteel,room);
            Rail(new Vector3(x+.14f,1.448f,z),new Vector3(x+.031f,1.448f,z),.014f,brass,room);
            Cylinder("Insulated neck collar",baseAt+Vector3.up*.198f,.047f,.023f,dark,false,room);
        }
    }
}
