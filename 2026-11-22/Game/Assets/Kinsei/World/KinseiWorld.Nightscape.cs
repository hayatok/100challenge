using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public sealed partial class KinseiWorld
{
    // The main camera clears to a solid colour. A finite, inward-facing surround stays
    // inside its 110 m clip distance; the two short-range receiver cameras cannot see it.
    KinseiNightAssets nightAssets;

    void BuildNightscape()
    {
        var owner = nightAssets = new KinseiNightAssets(new GameObject("宵待町・夜景").transform);
        owner.Root.SetParent(transform, false);
        var upper = new GameObject("生活階・指揮時の屋根断面").transform;
        upper.SetParent(owner.Root, false);
        overhead.Add(upper.gameObject);

        var glassImage = Resources.Load<Texture2D>("KinseiNightscape/UpperGlass");
        var airImage = Resources.Load<Texture2D>("KinseiNightscape/EveningAir");
        var airShader = Resources.Load<Shader>("KinseiNightscape/EveningAtmosphere");
        if (airImage && airShader)
        {
            var sky = owner.Keep(new Material(airShader) { name = "宵待町・雲底", mainTexture = airImage });
            dawnSky=sky;
            CreateEveningSurround(owner, sky);
        }

        var lime = owner.Keep(Mat("雨染みの上階モルタル", "#776A5D", .04f, .28f));
        var facing = Resources.Load<Texture2D>("KinseiSurfaces/beige_wall_002_Diffuse");
        if (facing) lime.mainTexture = facing;
        var zinc = owner.Keep(Mat("煤けた水切り・亜鉛", "#657377", .48f, .43f));
        var sash = owner.Keep(Mat("古い木製建具", "#392F29", .1f, .34f));
        var distant = owner.Keep(Mat("遠い屋上の青灰", "#48505B", .06f, .25f));
        var home = owner.Keep(Mat("室内から透ける型板ガラス", "#BAA991", .05f, .31f));
        dawnHome=home;
        if (glassImage)
        {
            home.mainTexture = glassImage;
            home.SetTexture("_EmissionMap", glassImage);
            home.EnableKeyword("_EMISSION");
            home.SetColor("_EmissionColor", new Color(.63f, .57f, .49f));
        }

        BuildStreetEnds(lime,zinc,sash,home,distant);

        var walls = new NightGeometry();
        var metal = new NightGeometry();
        var frames = new NightGeometry();
        var panes = new NightGeometry();

        for (int shop = 0; shop < 3; shop++)
        {
            float door = (shop - 1) * 16;
            float centre = door + (shop == 1 ? -.85f : .8f);
            // Keep the full side alleys and the view of the railway between addresses.
            float width = shop == 2 ? 5.0f : 5.8f;
            float floorTop = shop == 2 ? 5.57f : 5.83f;
            float front = -15.43f;
            walls.Block(new Vector3(centre, (3.56f + floorTop) * .5f, -17.31f),
                new Vector3(width, floorTop - 3.56f, 3.7f));
            metal.Block(new Vector3(centre, floorTop + .06f, -17.27f), new Vector3(width + .30f, .12f, 4.13f));
            for (int bay = 0; bay < 2; bay++)
            {
                float x = centre + (bay == 0 ? -1.18f : 1.18f);
                BuildDomesticWindow(frames, metal, panes, new Vector3(x, 4.71f, front),
                    shop == 2 ? 1.60f : 1.84f, shop == 2 ? .95f : 1.17f, 1, (shop + bay * 3) % 4);
            }

            float end = centre + width / 2 - .19f;
            metal.Tube(new Vector3(end, 5.48f, front+.04f), new Vector3(end, 3.68f, front+.04f), .052f);
            metal.Tube(new Vector3(end, 3.68f, front+.04f), new Vector3(end, 3.51f, front+.21f), .052f);
            metal.Tube(new Vector3(end, 3.51f, front+.21f), new Vector3(end, 3.51f, -14.06f), .052f);
            // Standoffs and a short dipped power feed behind each existing shop fascia.
            for (int side = -1; side <= 1; side += 2)
            {
                float anchor = door + side*3.24f;
                metal.Tube(new Vector3(anchor, 3.23f, -14.02f), new Vector3(anchor, 3.51f, -14.43f), .032f);
            }
            for (int section = 0; section < 5; section++)
            {
                float t = section/5f, next = (section+1)/5f;
                metal.Tube(SignFeed(door, t), SignFeed(door, next), .019f);
            }
        }

        // The club already has a six-metre shell. Its wardrobe and stair lights live in
        // two projecting bays above the display glass, away from the entrance lettering.
        for (int side = -1; side <= 1; side += 2)
            BuildDomesticWindow(frames, metal, panes, new Vector3(side*5.41f, 4.60f, -8.39f),
                2.44f, .91f, -1, side < 0 ? 2 : 3);

        // Service the blade sign from the club wall. The mounting lugs stay behind the
        // enamel housing, leaving the face and the pavement below clear.
        metal.Block(new Vector3(8.03f,5.40f,-8.34f),new Vector3(.23f,.30f,.15f));
        for(int mount=0;mount<2;mount++)
        {
            float h=4.58f+mount*.89f;
            metal.Tube(new Vector3(8.43f,h,-8.21f),new Vector3(8.43f,h,-8.50f),.033f);
        }
        metal.Tube(new Vector3(8.03f,5.40f,-8.39f),new Vector3(8.03f,5.10f,-8.39f),.025f);
        metal.Tube(new Vector3(8.03f,5.10f,-8.39f),new Vector3(8.37f,5.10f,-8.49f),.025f);

        walls.Upload(upper, lime, owner);
        metal.Upload(upper, zinc, owner);
        frames.Upload(upper, sash, owner);
        panes.Upload(upper, home, owner);

        // Reuse the old apartment coordinates. A few occupied windows on the near row
        // gain deep reveals. The original dark and lit neighbours stay in place.
        var farMetal = new NightGeometry();
        var farFrames = new NightGeometry();
        var farGlass = new NightGeometry();
        var skyline = new NightGeometry();
        for (int block = 0; block < 11; block++)
        {
            float x = -50 + block * 10.1f, z = -37 - (block * 7 % 9);
            int floors = 3 + block * 5 % 4;
            for (int floor = 1; floor < floors; floor += 2)
            {
                int col = (block + 2*floor) % 4;
                BuildDomesticWindow(farFrames, farMetal, farGlass,
                    new Vector3(x-3+col*2, 1.68f+2.9f*floor, z+2.565f),
                    1.51f, 1.24f, 1, (floor+block)%4);
            }
            // Beyond the railway's existing walk-ups: set-back roofs and water-tank rooms,
            // separated in world space so their silhouettes overlap differently as one walks.
            float rear = -55 - 3*(block%3), height = 11.3f + (block*7%12);
            skyline.Block(new Vector3(x+2.2f,height/2,rear), new Vector3(7.1f+block%4,height,6.2f));
            skyline.Block(new Vector3(x+1.5f,height+.68f,rear+.45f), new Vector3(2.65f,1.36f,2.1f));
            if (block%3==0)
                skyline.Tube(new Vector3(x+2,height+1.3f,rear),new Vector3(x+2,height+3.1f,rear),.10f);
        }
        skyline.Upload(owner.Root, distant, owner);
        farFrames.Upload(owner.Root, sash, owner);
        farMetal.Upload(owner.Root, zinc, owner);
        farGlass.Upload(owner.Root, home, owner);

        // Vertex lights give the two outlying storefronts a local pool on the pavement
        // and faces. No shadow maps, per-frame updates, or full-screen colour changes.
        var west = LightAt("ロータス・庇の反射光", new Vector3(-15.0f,3.32f,-13.32f),
            new Color(1f,.78f,.58f),1.18f,5.0f);
        west.renderMode=LightRenderMode.ForceVertex;
        var east = LightAt("送像所・窓口の反射光", new Vector3(15.35f,3.24f,-13.39f),
            new Color(.69f,.83f,.92f),1.10f,4.8f);
        east.renderMode=LightRenderMode.ForceVertex;
    }

    static Vector3 SignFeed(float x, float t)
    {
        return new Vector3(x-2.89f+1.7f*t, 3.48f-.11f*Mathf.Sin(Mathf.PI*t), -14.12f-.56f*t);
    }

    static void BuildDomesticWindow(NightGeometry frame, NightGeometry steel, NightGeometry glazing,
        Vector3 wall, float width, float height, int outward, int print)
    {
        Vector3 face = Vector3.forward * outward;
        Vector3 rim = wall + face*.22f;
        float halfW = width*.5f, halfH = height*.5f;
        frame.Block(wall + face*.036f, new Vector3(width+.16f,height+.17f,.095f));
        glazing.Pane(wall+face*.102f, Vector3.right*(outward*halfW),Vector3.up*halfH,print);
        for(int side=-1;side<=1;side+=2)
        {
            frame.Block(rim+Vector3.right*(side*(halfW+.025f)), new Vector3(.082f,height+.13f,.27f));
            frame.Block(rim+Vector3.up*(side*(halfH+.026f)), new Vector3(width+.13f,.078f,.27f));
        }
        if(print==0 || print==2)
        {
            // A lamp pull hangs inside the wooden sash, in front of the diffused image.
            Vector3 pull=wall+face*.152f+Vector3.right*(halfW*.66f)+Vector3.up*(halfH*.60f);
            frame.Tube(pull,pull-Vector3.up*.23f,.009f);
            frame.Block(pull-Vector3.up*.25f,new Vector3(.032f,.048f,.028f));
        }
        frame.Block(rim, new Vector3(.043f,height,.071f));
        frame.Block(rim+Vector3.up*(height*.18f),new Vector3(width,.035f,.060f));
        steel.Block(rim-Vector3.up*(halfH+.092f)+face*.06f,new Vector3(width+.31f,.068f,.40f));
        steel.Block(rim+Vector3.up*(halfH+.13f)+face*.045f,new Vector3(width+.25f,.047f,.40f));
    }

    static void CreateEveningSurround(KinseiNightAssets owner, Material material)
    {
        const int slices=48, rings=14;
        var points=new Vector3[(slices+1)*(rings+1)];
        var uv=new Vector2[points.Length];
        var faces=new int[slices*rings*6];
        int triangle=0;
        for(int row=0;row<=rings;row++)
        {
            float v=row/(float)rings;
            float elevation=Mathf.Lerp(-Mathf.PI*.5f,Mathf.PI*.5f,v);
            for(int slice=0;slice<=slices;slice++)
            {
                float u=slice/(float)slices, a=2*Mathf.PI*u;
                int n=row*(slices+1)+slice;
                points[n]=new Vector3(Mathf.Cos(elevation)*Mathf.Sin(a),Mathf.Sin(elevation),
                    Mathf.Cos(elevation)*Mathf.Cos(a))*73f+new Vector3(0,0,-12);
                uv[n]=new Vector2(u,Mathf.Clamp01(elevation/(Mathf.PI*.5f)));
                if (slice==slices || row==rings) continue;
                faces[triangle++]=n;faces[triangle++]=n+slices+2;faces[triangle++]=n+1;
                faces[triangle++]=n;faces[triangle++]=n+slices+1;faces[triangle++]=n+slices+2;
            }
        }
        var mesh=owner.Keep(new Mesh { name="宵の雲層・球面",vertices=points,uv=uv,triangles=faces });
        var shell=new GameObject(mesh.name);
        shell.transform.SetParent(owner.Root,false);
        shell.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=shell.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
        renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
        renderer.lightProbeUsage=LightProbeUsage.Off;renderer.reflectionProbeUsage=ReflectionProbeUsage.Off;
    }

    sealed class NightGeometry
    {
        readonly List<Vector3> positions=new List<Vector3>();
        readonly List<Vector3> normals=new List<Vector3>();
        readonly List<Vector2> uv=new List<Vector2>();
        readonly List<int> triangles=new List<int>();

        void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 normal,Rect rect)
        {
            int n=positions.Count;
            positions.Add(a);positions.Add(b);positions.Add(c);positions.Add(d);
            for(int i=0;i<4;i++)normals.Add(normal);
            uv.Add(new Vector2(rect.xMin,rect.yMin));uv.Add(new Vector2(rect.xMax,rect.yMin));
            uv.Add(new Vector2(rect.xMax,rect.yMax));uv.Add(new Vector2(rect.xMin,rect.yMax));
            triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
        }

        void Face(Vector3 p,Vector3 halfRight,Vector3 halfUp,Rect rect)
        {
            Quad(p-halfRight-halfUp,p+halfRight-halfUp,p+halfRight+halfUp,p-halfRight+halfUp,
                Vector3.Cross(halfRight,halfUp).normalized,rect);
        }

        public void Pane(Vector3 p,Vector3 halfRight,Vector3 halfUp,int tile)
        {
            const float inset=8f/1536f;
            Face(p,halfRight,halfUp,new Rect((tile%2)*.5f+inset,(1-tile/2)*.5f+inset,.5f-2*inset,.5f-2*inset));
        }

        public void Gable(Vector3 centre,int end,float depth,float rise)
        {
            Vector3 a=centre+Vector3.forward*(end*depth*.5f), b=centre-Vector3.forward*(end*depth*.5f);
            Vector3 peak=centre+Vector3.up*rise;
            Quad(a,b,peak,peak,Vector3.right*end,new Rect(0,0,1,1));
        }

        public void Block(Vector3 p,Vector3 size,float metresPerRepeat=0)
        {
            Vector3 x=Vector3.right*(size.x*.5f),y=Vector3.up*(size.y*.5f),z=Vector3.forward*(size.z*.5f);
            var r=new Rect(0,0,1,1);
            if(metresPerRepeat>0)r.size=new Vector2(size.x,size.y)/metresPerRepeat;
            Face(p+z,x,y,r);Face(p-z,-x,y,r);
            if(metresPerRepeat>0)r.size=new Vector2(size.z,size.y)/metresPerRepeat;
            Face(p+x,-z,y,r);Face(p-x,z,y,r);
            if(metresPerRepeat>0)r.size=new Vector2(size.x,size.z)/metresPerRepeat;
            Face(p+y,x,-z,r);Face(p-y,x,z,r);
        }

        public void Tube(Vector3 a, Vector3 b, float radius)
        {
            Vector3 axis=(b-a).normalized;
            Vector3 x=Vector3.Cross(axis,Mathf.Abs(axis.y)>.9f?Vector3.forward:Vector3.up).normalized*radius;
            Vector3 z=Vector3.Cross(axis,x);
            for(int i=0;i<8;i++)
            {
                float t=i*Mathf.PI/4f,next=(i+1)*Mathf.PI/4f;
                Vector3 r=x*Mathf.Cos(t)+z*Mathf.Sin(t), s=x*Mathf.Cos(next)+z*Mathf.Sin(next);
                Quad(a+r,a+s,b+s,b+r,(r+s).normalized,new Rect(0,0,1,1));
            }
        }

        public void Upload(Transform parent,Material material,KinseiNightAssets owner)
        {
            var mesh=owner.Keep(new Mesh { name=material.name });
            mesh.SetVertices(positions);mesh.SetNormals(normals);mesh.SetUVs(0,uv);mesh.SetTriangles(triangles,0);
            var part=new GameObject(material.name);part.transform.SetParent(parent,false);
            part.AddComponent<MeshFilter>().sharedMesh=mesh;
            var renderer=part.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
            renderer.shadowCastingMode=ShadowCastingMode.Off;
        }
    }
}

internal sealed class KinseiNightAssets
{
    public readonly Transform Root;
    public KinseiNightAssets(Transform root) { Root = root; }
    readonly List<Object> owned=new List<Object>();
    public T Keep<T>(T asset) where T:Object { owned.Add(asset); return asset; }
    public void Release() { foreach(var item in owned) if(item)Object.Destroy(item); owned.Clear(); }
}


