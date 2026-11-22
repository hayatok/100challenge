using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public sealed partial class KinseiWorld
{
    Light frontageFill, displayFill;

    void BuildFrontage()
    {
        var stone=nightAssets.Keep(Mat("金星玄関・研ぎ出し石","#D7C8B2",.04f,.35f));
        var scan=Resources.Load<Texture2D>("KinseiFrontage/Stone");
        var grain=Resources.Load<Texture2D>("KinseiFrontage/StoneNormal");
        if(scan){stone.mainTexture=scan;stone.color=Color.white;}
        if(grain){stone.SetTexture("_BumpMap",grain);stone.SetFloat("_BumpScale",.30f);stone.EnableKeyword("_NORMALMAP");}
        var baseStone=nightAssets.Keep(new Material(stone){name="墨色の人造石巾木",color=new Color(.14f,.15f,.16f)});
        var skirtingScan=Resources.Load<Texture2D>("KinseiFrontage/Skirting");
        if(skirtingScan){baseStone.mainTexture=skirtingScan;baseStone.color=Color.white;}
        baseStone.DisableKeyword("_NORMALMAP");baseStone.SetTexture("_BumpMap",null);
        baseStone.SetFloat("_Glossiness",.46f);
        var bronze=nightAssets.Keep(Mat("古美色の真鍮","#A88D69",.64f,.41f));
        var patina=Resources.Load<Texture2D>("KinseiFrontage/Brass");
        if(patina){bronze.mainTexture=patina;bronze.color=new Color(.88f,.84f,.78f);}
        var enamel=nightAssets.Keep(Mat("庇の焼付琺瑯","#948C7D",.19f,.39f));
        var opal=nightAssets.Keep(Mat("白熱灯の乳白硝子","#EEE4CF",0,.40f,1.15f));
        var panes=nightAssets.Keep(Mat("修繕した陳列窓の板硝子","#CBD1C7",.07f,.76f));
        var tint=panes.color;tint.a=.15f;panes.color=tint;
        panes.SetFloat("_Mode",3);panes.SetOverrideTag("RenderType","Transparent");
        panes.SetInt("_SrcBlend",(int)BlendMode.One);panes.SetInt("_DstBlend",(int)BlendMode.OneMinusSrcAlpha);
        panes.SetInt("_ZWrite",0);panes.EnableKeyword("_ALPHAPREMULTIPLY_ON");panes.renderQueue=(int)RenderQueue.Transparent;

        var ashlar=new NightGeometry();var skirting=new NightGeometry();var metal=new NightGeometry();
        var backing=new NightGeometry();var reveal=new NightGeometry();var glazing=new NightGeometry();
        for(int side=-1;side<=1;side+=2)
        {
            // A 3.6 m entry remains between the two structural wall colliders.
            // The facing is cut around each display, leaving a 270 mm deep reveal.
            const float sill=.88f, head=3.54f;
            float[] cuts={1.80f,2.94f,4.12f,5.50f,6.88f,7.94f,9f};
            float[] courses={.46f,sill,1.84f,2.70f,head,4.48f,5.40f};
            for(int i=0;i<cuts.Length-1;i++)
            {
                float x=side*(cuts[i]+cuts[i+1])*.5f,w=cuts[i+1]-cuts[i];
                skirting.Block(new Vector3(x,.225f,-8.11f),new Vector3(w-.007f,.445f,.235f),.50f);
                for(int j=0;j<courses.Length-1;j++)
                {
                    if(i>=2 && i<=3 && j>=1 && j<=3)continue;
                    float y=(courses[j]+courses[j+1])*.5f,h=courses[j+1]-courses[j];
                    ashlar.Block(new Vector3(x,y,-8.077f),new Vector3(w-.010f,h-.010f,.225f),.64f);
                }
            }
            float center=side*5.50f;
            backing.Block(new Vector3(side*5.4f,2.70f,-7.81f),new Vector3(7.2f,5.4f,.12f));
            // The rear face of each case stays behind the printed poster and the CRT chassis.
            reveal.Block(new Vector3(center,2.21f,-7.89f),new Vector3(2.78f,2.68f,.09f));
            for(int edge=-1;edge<=1;edge+=2)
            {
                reveal.Block(new Vector3(center+edge*1.365f,2.21f,-8.05f),new Vector3(.065f,2.70f,.34f));
                metal.Block(new Vector3(center+edge*1.398f,2.21f,-8.21f),new Vector3(.042f,2.76f,.065f),.24f);
            }
            foreach(float y in new[]{sill,head})
            {
                reveal.Block(new Vector3(center,y,-8.05f),new Vector3(2.77f,.096f,.34f));
                metal.Block(new Vector3(center,y,-8.216f),new Vector3(2.84f,.055f,.076f),.24f);
            }
            metal.Block(new Vector3(center,sill-.09f,-8.15f),new Vector3(2.89f,.045f,.30f),.24f);
            glazing.Pane(new Vector3(center,2.21f,-8.184f),Vector3.left*1.335f,Vector3.up*1.284f,0);
            // Narrow stiles and clear glass leave the held-open pivot doors readable from inside.
            float jamb=side*1.48f;
            foreach(float z in new[]{-8.59f,-7.41f})
                metal.Block(new Vector3(jamb,1.81f,z),new Vector3(.056f,3.41f,.045f),.24f);
            foreach(float y in new[]{.13f,.92f,3.50f})
                metal.Block(new Vector3(jamb,y,-8),new Vector3(.056f,.047f,1.22f),.24f);
            glazing.Pane(new Vector3(jamb,1.81f,-8),Vector3.forward*.57f,Vector3.up*1.65f,0);
            glazing.Pane(new Vector3(jamb,1.81f,-8),Vector3.back*.57f,Vector3.up*1.65f,0);
            metal.Tube(new Vector3(jamb-side*.072f,.88f,-8.51f),new Vector3(jamb-side*.072f,1.46f,-8.51f),.018f);
        }
        // A dark inset carries the existing lettering. The old sign stays at its original address.
        reveal.Block(new Vector3(0,4.49f,-8.15f),new Vector3(3.89f,1.01f,.58f));
        metal.Block(new Vector3(0,4.99f,-8.445f),new Vector3(3.95f,.036f,.060f),.24f);
        metal.Block(new Vector3(0,3.99f,-8.445f),new Vector3(3.95f,.036f,.060f),.24f);
        ashlar.Upload(transform,stone,nightAssets);
        var stoneMesh=transform.GetChild(transform.childCount-1).GetComponent<MeshFilter>().sharedMesh;
        stoneMesh.RecalculateTangents();
        skirting.Upload(transform,baseStone,nightAssets);
        transform.GetChild(transform.childCount-1).GetComponent<MeshFilter>().sharedMesh.RecalculateTangents();
        metal.Upload(transform,bronze,nightAssets);backing.Upload(transform,cream,nightAssets);
        reveal.Upload(transform,dark,nightAssets);glazing.Upload(transform,panes,nightAssets);
        BuildPorch(enamel,bronze,opal);
        LightFrontage();
    }

    void BuildPorch(Material enamel,Material bronze,Material opal)
    {
        var roof=new GameObject("玄関の片持ち庇・指揮時断面").transform;
        roof.SetParent(transform,false);overhead.Add(roof.gameObject);
        // Three pressed returns form one closed, rounded canopy. Only the narrow
        // lower lip uses brass; the broad soffit is dull enamel.
        var layers=new[]{new Vector3(2.91f,3.77f,-10.13f),new Vector3(2.97f,3.81f,-10.19f),
            new Vector3(2.97f,3.94f,-10.19f),new Vector3(2.90f,3.99f,-10.12f)};
        var points=new List<Vector3>();var uv=new List<Vector2>();
        var triangles=new List<int>();var trim=new List<int>();
        const int arcs=8;
        for(int layer=0;layer<layers.Length;layer++)
        {
            var cut=layers[layer];
            points.Add(new Vector3(-cut.x,cut.y,-8.11f));
            for(int s=-1;s<=1;s+=2)
                for(int k=0;k<=arcs;k++)
                {
                    float a=(s==-1?k:arcs-k)*Mathf.PI/(arcs*2);
                    points.Add(new Vector3(s*(cut.x-.39f+.39f*Mathf.Cos(a)),cut.y,cut.z+.39f-.39f*Mathf.Sin(a)));
                }
            points.Add(new Vector3(cut.x,cut.y,-8.11f));
        }
        int ring=(arcs+1)*2+2;
        for(int i=0;i<points.Count;i++)uv.Add(new Vector2(points[i].x,points[i].z)*1.2f);
        for(int level=0;level<layers.Length-1;level++)
            for(int i=0;i<ring;i++)
            {
                int a=level*ring+i,b=level*ring+(i+1)%ring;
                var face=level==0?trim:triangles;
                face.AddRange(new[]{a,a+ring,b,b,a+ring,b+ring});
            }
        for(int k=1;k<ring-1;k++)
        {
            triangles.AddRange(new[]{0,k,k+1});
            int end=(layers.Length-1)*ring;
            triangles.AddRange(new[]{end,end+k+1,end+k});
        }
        var mesh=nightAssets.Keep(new Mesh{name="琺瑯庇の折り返し"});
        mesh.SetVertices(points);mesh.SetUVs(0,uv);mesh.subMeshCount=2;
        mesh.SetTriangles(triangles,0);mesh.SetTriangles(trim,1);mesh.RecalculateNormals();
        var shell=roof.gameObject.AddComponent<MeshFilter>();shell.sharedMesh=mesh;
        roof.gameObject.AddComponent<MeshRenderer>().sharedMaterials=new[]{enamel,bronze};
        var sockets=new NightGeometry();
        foreach(float x in new[]{-2.02f,0,2.02f})
        {
            sockets.Block(new Vector3(x,3.744f,-9.79f),new Vector3(.30f,.066f,.30f));
            sockets.Tube(new Vector3(x,3.722f,-9.79f),new Vector3(x,3.645f,-9.79f),.121f);
        }
        sockets.Upload(roof,bronze,nightAssets);
        PorchGlobes(roof,opal);
        // A single fine jade tube identifies the TV bay; the housing screens its rear glow.
        var casing=new NightGeometry();var neon=new NightGeometry();
        casing.Block(new Vector3(5.5f,3.62f,-8.27f),new Vector3(2.02f,.081f,.14f));
        neon.Tube(new Vector3(4.56f,3.609f,-8.346f),new Vector3(6.44f,3.609f,-8.346f),.012f);
        casing.Upload(transform,bronze,nightAssets);neon.Upload(transform,cyan,nightAssets);
        var reflector=new NightGeometry();
        reflector.Block(new Vector3(5.50f,3.50f,-8.19f),new Vector3(2.28f,.032f,.115f));
        reflector.Upload(transform,opal,nightAssets);
    }

    void PorchGlobes(Transform roof,Material opal)
    {
        const int segments=16;
        var vertices=new List<Vector3>();var normals=new List<Vector3>();var indices=new List<int>();
        foreach(float x in new[]{-2.02f,0,2.02f})
        {
            int offset=vertices.Count;
            for(int row=0;row<=8;row++)
            for(int col=0;col<segments;col++)
            {
                float lat=row*Mathf.PI/8,lon=col*2*Mathf.PI/segments;
                var n=new Vector3(Mathf.Sin(lat)*Mathf.Cos(lon),Mathf.Cos(lat),Mathf.Sin(lat)*Mathf.Sin(lon));
                vertices.Add(new Vector3(x,3.594f,-9.79f)+Vector3.Scale(n,new Vector3(.12f,.105f,.12f)));
                normals.Add(new Vector3(n.x,n.y*.12f/.105f,n.z).normalized);
                if(row==8)continue;
                int a=offset+row*segments+col,b=offset+row*segments+(col+1)%segments;
                if(row>0)indices.AddRange(new[]{a,b,a+segments});
                if(row<7)indices.AddRange(new[]{b,b+segments,a+segments});
            }
        }
        var mesh=nightAssets.Keep(new Mesh{name="三連乳白硝子"});
        mesh.SetVertices(vertices);mesh.SetNormals(normals);mesh.SetTriangles(indices,0);
        Surface("吊下げ三灯",mesh,opal,roof,false);
    }

    void LightFrontage()
    {
        // Keep both existing light names so the dawn programme still dims them.
        var porch=LightAt("Entrance amber",new Vector3(.68f,3.56f,-9.80f),new Color(1,.91f,.79f),2.85f,7.0f);
        porch.type=LightType.Spot;porch.spotAngle=114;porch.innerSpotAngle=78;
        porch.transform.LookAt(transform.TransformPoint(new Vector3(1.32f,1.27f,-11.07f)));
        var jade=LightAt("Street jade neon",new Vector3(6.91f,2.52f,-8.70f),new Color(.43f,.86f,.74f),.59f,3.35f);
        jade.type=LightType.Spot;jade.spotAngle=59;jade.innerSpotAngle=31;
        jade.transform.LookAt(transform.TransformPoint(new Vector3(7.05f,.10f,-10.02f)));
        jade.renderMode=LightRenderMode.ForceVertex;
        // Reflected shop window light reaches faces from the street side and the
        // near shoulder of a navy jacket. Vertex fill adds no shadow or pixel pass.
        frontageFill=LightAt("対面の窓から返る拡散光",new Vector3(2.65f,2.70f,-13.57f),new Color(.94f,.96f,1),2.23f,8.28f);
        frontageFill.renderMode=LightRenderMode.ForceVertex;
        displayFill=LightAt("街頭受像機・展示窓の間接灯",new Vector3(5.12f,3.12f,-8.58f),new Color(1,.93f,.84f),1.38f,4.95f);
        displayFill.renderMode=LightRenderMode.ForceVertex;
    }
}
