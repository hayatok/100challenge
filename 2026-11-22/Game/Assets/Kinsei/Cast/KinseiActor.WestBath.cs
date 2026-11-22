using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public sealed partial class KinseiActor
{
    Transform westLoad;
    bool westFumiko,westKiichi,westSeo;
    Vector3 westGrip;
    float westCarrySway;
    int westRimShape=-1;
    static readonly Vector3 WestRimContact=new Vector3(0,-.10975f,.00825f);
    void UpgradeWestSkin(bool boss,bool makabe,bool kaji,int variant)
    {
        string actual=roleName;
        if(actual=="west-fumiko") {roleName="resident";UpgradeSkin(false,false,false,0);roleName=actual;}
        else if(actual=="west-kiichi")UpgradeSkin(false,false,true,0);
        else if(actual=="seo")UpgradeSkin(false,false,false,0);
        else UpgradeSkin(boss,makabe,kaji,variant);
    }
    void DressWestBath(string role,int variant)
    {
        westFumiko=role=="west-fumiko";westKiichi=role=="west-kiichi";westSeo=role=="seo";
        if(!westFumiko&&!westKiichi&&!westSeo)return;
        string cut=westFumiko?"Fumiko":westKiichi?"Kiichi":"Seo";
        foreach(var renderer in GetComponentsInChildren<SkinnedMeshRenderer>())
            if(renderer.transform.parent==transform && renderer.name.StartsWith("Tailored "))renderer.enabled=false;
        var data=Resources.Load<TextAsset>("KinseiWestCast/"+cut+"Cut");
        if(data!=null)WestDressMesh(data,cut);
        Material knit=WestMaterial(westFumiko?"文子・深緑の編地":"喜一・茶の綾織",westFumiko?new Color(.12f,.23f,.19f):new Color(.36f,.23f,.14f),.10f);
        knit.mainTexture=Resources.Load<Texture2D>("KinseiWestCast/TerryCotton");
        Material ivory=WestMaterial("銭湯客の生成りの肌着",new Color(.79f,.75f,.63f),.08f);ivory.mainTexture=Resources.Load<Texture2D>("KinseiWestCast/TerryCotton");
        if(!westSeo)
        {
            Shape("丸首の生成り肌着",chest,ivory,new[]{R(.10f,.12f,.104f),R(.28f,.15f,.111f),R(.36f,.155f,.102f),R(.408f,.066f,.067f),R(.444f,.051f,.050f)},32);
            for(int side=-1;side<=1;side+=2)
            {
                float x=side*.105f;
                WestPocket(chest,knit,x,westFumiko?-.045f:.256f,westFumiko?.082f:.075f,.079f);
                if(westKiichi)WestPocket(chest,knit,x,-.054f,.085f,.083f);
                if(westFumiko)WestTube("文子・カーディガンの前立て",chest,knit,new[]{V(side*.074f,.397f,.095f),V(side*.063f,.31f,.135f),V(side*.016f,.16f,.139f),V(side*.016f,-.14f,.125f)},.0043f);
                else Patch("喜一・開襟の返り",chest,knit,new[]{V(side*.062f,.410f,.088f),V(side*.126f,.347f,.111f),V(side*.052f,.292f,.142f),V(side*.037f,.354f,.138f)});
            }
            Patch("湯上がり着の前立て",chest,knit,new[]{V(-.022f,westFumiko?.16f:.332f,.140f),V(.022f,westFumiko?.16f:.332f,.140f),V(.022f,-.145f,.124f),V(-.022f,-.145f,.124f)});
            Material button=WestMaterial("古い水牛調の服釦",new Color(.16f,.12f,.075f),.24f);
            for(float y=westFumiko?.104f:.290f;y>-.145f;y-=.072f)Oval("湯上がり着の丸釦",chest,button,V(.006f,y,.143f),V(.006f,.006f,.002f));
        }
        else
        {
            var throat=WestMaterial("瀬尾・開襟の首元",new Color(.54f,.37f,.27f),.19f);
            Shape("瀬尾・シャンパンシャツの開いた首元",chest,throat,new[]{R(.328f,.030f,.069f),R(.403f,.046f,.063f),R(.454f,.048f,.049f)},24);
            hair.color=new Color(.22f,.215f,.195f);
        }
        if(westFumiko)
        {
            foreach(var r in head.GetComponentsInChildren<MeshRenderer>())if(r.sharedMaterial==hair)r.gameObject.SetActive(false);
            Transform curls=new GameObject("文子・短い灰混じりパーマ").transform;curls.SetParent(head,false);
            Material charcoal=WestMaterial("文子・柔らかな黒灰の髪",new Color(.105f,.095f,.08f),.19f);
            Material silver=WestMaterial("文子・パーマに混じる白髪",new Color(.25f,.24f,.21f),.17f);
            for(int row=0;row<5;row++)for(int i=0;i<18;i++)
            {
                float a=i*Mathf.PI*2/18,latitude=.16f+row*.255f;
                float radial=Mathf.Cos(latitude);Vector3 p=V(Mathf.Cos(a)*.087f*radial,.129f+Mathf.Sin(latitude)*.086f,-.008f+Mathf.Sin(a)*.080f*radial);
                if(p.z>.023f && p.y<.165f)continue;
                Oval("短く巻いたパーマ",curls,(i+row)%7==0?silver:charcoal,p,V(.015f,.018f,.015f));
            }
            Oval("パーマの丸い頭頂",curls,charcoal,V(0,.212f,-.008f),V(.043f,.022f,.040f));
            MergeSurfaces(curls);
            westLoad=WestBasket();westGrip=V(0,.432f,0);
            transform.localScale=Vector3.Scale(transform.localScale,V(.91f,.92f,.91f));
        }
        else if(westKiichi)
        {
            hair.color=new Color(.83f,.81f,.76f);hair.mainTexture=Resources.Load<Texture2D>("KinseiWestCast/SilverHair");
            westLoad=WestBasin();westGrip=V(-.11667262f,.087f,.11667262f);
            if(leftHandRenderer!=null)westRimShape=BuildWestRimGrasp(leftHandRenderer.sharedMesh);
            transform.localScale=Vector3.Scale(transform.localScale,V(1.035f,.97f,1.035f));
        }
        else transform.localScale=Vector3.Scale(transform.localScale,V(1.045f,1.015f,1.025f));
        PoseWestBath("idle",0);
    }
    void WestDressMesh(TextAsset data,string name)
    {
        using(var reader=new BinaryReader(new MemoryStream(data.bytes)))
        {
            int count=reader.ReadInt32(),indexCount=reader.ReadInt32();
            if(count<1||count>60000||indexCount<3||indexCount>300000||data.bytes.Length!=8+52*count+2*indexCount)throw new InvalidDataException("Invalid west wardrobe "+name);
            var p=new Vector3[count];var n=new Vector3[count];var uv=new Vector2[count];var weights=new BoneWeight[count];
            for(int i=0;i<count;i++)
            {
                p[i]=V(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());n[i]=V(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());uv[i]=new Vector2(reader.ReadSingle(),reader.ReadSingle());
                weights[i]=new BoneWeight{boneIndex0=reader.ReadByte(),boneIndex1=reader.ReadByte(),boneIndex2=reader.ReadByte(),boneIndex3=reader.ReadByte(),weight0=reader.ReadSingle(),weight1=reader.ReadSingle(),weight2=reader.ReadSingle(),weight3=reader.ReadSingle()};
            }
            var indices=new int[indexCount];for(int i=0;i<indexCount;i++)indices[i]=reader.ReadUInt16();
            var bones=new[]{body,chest,la,le,ra,re,ll,lk,rl,rk};var binds=new Matrix4x4[bones.Length];for(int i=0;i<bones.Length;i++)binds[i]=bones[i].worldToLocalMatrix*transform.localToWorldMatrix;
            var mesh=new Mesh{name=name+" final skinned clothing",vertices=p,normals=n,uv=uv,triangles=indices,boneWeights=weights,bindposes=binds};mesh.RecalculateTangents();mesh.RecalculateBounds();
            var o=new GameObject(name+"・最終スキン衣装");o.transform.SetPositionAndRotation(transform.position,transform.rotation);o.transform.SetParent(body,true);
            var material=WestMaterial(name+"の実衣装",Color.white,.13f);material.mainTexture=Resources.Load<Texture2D>("KinseiWestCast/"+name+"Cloth");material.SetTexture("_BumpMap",Resources.Load<Texture2D>("KinseiWestCast/"+name+"ClothNormal"));material.EnableKeyword("_NORMALMAP");material.SetFloat("_BumpScale",.45f);
            var r=o.AddComponent<SkinnedMeshRenderer>();r.sharedMesh=mesh;r.sharedMaterial=material;r.bones=bones;r.rootBone=body;r.quality=SkinQuality.Bone4;r.localBounds=new Bounds(V(0,.8f,0),V(1.8f,2.1f,1.4f));
            FitHallCuffs(r);
        }
    }
    void PoseWestBath(string state,float speed)
    {
        if(westLoad==null)return;
        bool moving=state=="walk"||state=="run";
        westCarrySway=Mathf.Lerp(westCarrySway,moving?1:0,1-Mathf.Exp(-Time.deltaTime*9));
        float sway=(westFumiko?Mathf.Sin(phase):Mathf.Sin(phase*Mathf.PI*2))*westCarrySway;
        Quaternion pose=transform.rotation*(westFumiko?Quaternion.Euler(0,0,sway*1.5f):Quaternion.Euler(0,sway*.8f,0));
        Transform wrist=westFumiko?rh:lh;Transform shoulder=westFumiko?ra:la;Transform elbow=westFumiko?re:le;
        Vector3 desired=transform.TransformPoint(westFumiko?V(.375f,.82f,.105f):V(-.365f,1.04f,.42f));
        desired+=transform.up*(Mathf.Abs(sway)*.009f);
        Vector3 normal=westFumiko?transform.forward:pose*V(.70710678f,0,-.70710678f);
        Vector3 fingers=-transform.up;
        Vector3 contact=westFumiko?V(0,-.077f,.013f):WestRimContact;
        ReachPalm(shoulder,elbow,wrist,desired,normal,fingers,1,westFumiko?transform.right:-transform.right,contact);
        var hand=westFumiko?rightHandRenderer:leftHandRenderer;
        if(hand!=null)
        {
            for(int i=0;i<hand.sharedMesh.blendShapeCount;i++)hand.SetBlendShapeWeight(i,0);
            if(westFumiko)hand.SetBlendShapeWeight(0,78);
            else if(westRimShape>=0)hand.SetBlendShapeWeight(westRimShape,100);
        }
        Vector3 actual=wrist.TransformPoint(contact);
        // Seat the handle on the achieved palm even if a short actor hits IK reach limits.
        // Convert the local prop grip through the actor scale before applying rotation.
        westLoad.localScale=Vector3.one;
        westLoad.rotation=pose;Vector3 offset=westLoad.TransformVector(westGrip);
        westLoad.position=actual-offset;
    }
    // Kiichi only: full finger cross-sections keep their volume while the thumb
    // opposes across the rolled rim. Palm, wrist, skeleton and all other actors stay intact.
    static int BuildWestRimGrasp(Mesh hand)
    {
        Vector3[] original=hand.vertices,points=new Vector3[hand.vertexCount],delta=new Vector3[hand.vertexCount];
        for(int i=0;i<points.Length;i++)
        {
            Vector3 p=original[i];
            float thumb=Ease(.020f,.035f,-p.x)*(1-Ease(-.003f,.006f,p.z))*Ease(.064f,.090f,-p.y);
            float finger=Ease(.074f,.092f,-p.y)*(1-thumb);
            Vector3 first=V(0,-.079f,.005f)+Quaternion.Euler(12,0,0)*(p-V(0,-.079f,.005f));
            Vector3 distal=V(0,-.124f,.005f)+Quaternion.Euler(-48,0,0)*(first-V(0,-.124f,.005f));
            Vector3 four=Vector3.Lerp(first,distal,Ease(.115f,.145f,-p.y));
            Vector3 opposed=V(-.024f,-.068f,-.004f)+Quaternion.Euler(0,85,0)*(p-V(-.024f,-.068f,-.004f));
            points[i]=p+(four-p)*finger+(opposed-p)*thumb-Vector3.forward*(.011f*finger);
            // Actual imported surface/actor-scale contact calibration, measured in Editor.
            points[i]+=V(-.000187f,-.002872f,-.000795f)*thumb+V(-.000031f,-.000364f,.000941f)*finger;
            delta[i]=points[i]-p;
        }
        // Recalculate the actual posed surface normals instead of rotating only a
        // centreline. Keep unmodified palm/wrist normals byte-for-byte unchanged.
        var posed=new Mesh{vertices=points,triangles=hand.triangles};posed.RecalculateNormals();
        var normalDelta=posed.normals;var normals=hand.normals;
        for(int i=0;i<normalDelta.Length;i++)normalDelta[i]=delta[i].sqrMagnitude>.0000000001f?normalDelta[i]-normals[i]:Vector3.zero;
        int shape=hand.blendShapeCount;hand.AddBlendShapeFrame("喜一・琺瑯の縁を内外から挟む指",100,delta,normalDelta,null);
        if(Application.isPlaying)Destroy(posed);else DestroyImmediate(posed);
        return shape;
    }
    Material WestMaterial(string name,Color color,float smooth){var material=Mat(name,color,smooth);extraMaterials.Add(material);return material;}
    static void WestPocket(Transform parent,Material material,float x,float y,float width,float height)
    {
        float h=width/2;
        Patch("貼り付けの布ポケット",parent,material,new[]{V(x-h,y+height/2,.137f),V(x+h,y+height/2,.137f),V(x+h,y-height/2+.008f,.140f),V(x+h-.008f,y-height/2,.142f),V(x-h+.008f,y-height/2,.142f),V(x-h,y-height/2+.008f,.140f)});
        WestTube("ポケット口の縫い返し",parent,material,new[]{V(x-h,y+height/2,.140f),V(x+h,y+height/2,.140f)},.0015f);
    }
    Transform WestPropRoot(string name){var o=new GameObject(name).transform;o.SetPositionAndRotation(transform.position,transform.rotation);o.SetParent(body,true);return o;}
    Transform WestBasket()
    {
        var root=WestPropRoot("文子・右手の編み湯籠");
        var cane=WestMaterial("湯籠の籐",new Color(.48f,.32f,.15f),.19f);var pale=WestMaterial("湯籠の擦れた籐",new Color(.65f,.48f,.26f),.16f);
        for(int row=0;row<11;row++)
        {
            float y=.027f+row*.022f;var path=new Vector3[65];
            for(int i=0;i<=64;i++){float a=i*Mathf.PI*2/64;path[i]=V(Mathf.Cos(a)*(.112f+y*.10f),y,Mathf.Sin(a)*(.087f+y*.075f));}
            WestTube("横に編んだ籐",root,row%3==0?pale:cane,path,row==10?.004f:.0028f);
        }
        for(int col=0;col<40;col++)
        {
            float a=col*Mathf.PI*2/40;WestTube("縦の籐の芯",root,col%4==0?pale:cane,new[]{V(Mathf.Cos(a)*.113f,.025f,Mathf.Sin(a)*.089f),V(Mathf.Cos(a)*.124f,.14f,Mathf.Sin(a)*.097f),V(Mathf.Cos(a)*.137f,.25f,Mathf.Sin(a)*.106f)},.0026f);
        }
        for(int j=-4;j<=4;j++)WestTube("湯籠の底の編み",root,cane,new[]{V(-.10f,.027f,j*.018f),V(.10f,.027f,j*.018f)},.003f);
        for(int side=-1;side<=1;side+=2)
        {
            var path=new Vector3[25];for(int i=0;i<25;i++){float a=i*Mathf.PI/24;path[i]=V(Mathf.Cos(a)*.113f,.25f+Mathf.Sin(a)*.182f,side*.008f);}
            WestTube("握れる湯籠の持ち手",root,pale,path,.0045f);
        }
        WestTowel(root,V(-.037f,.18f,.015f),true);
        var soap=WestMaterial("石鹸の白い容器",new Color(.84f,.80f,.66f),.24f);Oval("角の丸い石鹸箱",root,soap,V(.035f,.21f,.045f),V(.038f,.018f,.028f));
        var amber=WestMaterial("文子の茶瓶の飴色ガラス",new Color(.26f,.13f,.035f),.62f);
        Shape("湯上がりの茶瓶",root,amber,new[]{R(.075f,.027f,.027f),R(.085f,.031f,.031f),R(.198f,.031f,.031f),R(.217f,.016f,.016f),R(.25f,.014f,.014f)},24).localPosition=V(.067f,0,-.037f);
        var cap=WestMaterial("茶瓶の濃茶の蓋",new Color(.10f,.075f,.041f),.27f);Shape("茶瓶の蓋",root,cap,new[]{R(.249f,.016f,.016f),R(.262f,.016f,.016f)},24).localPosition=V(.067f,0,-.037f);
        MergeSurfaces(root);return root;
    }
    Transform WestBasin()
    {
        var root=WestPropRoot("喜一・左手の薄青の琺瑯洗面器");var enamel=WestMaterial("古い薄青の琺瑯",new Color(.46f,.64f,.68f),.43f);var rim=WestMaterial("琺瑯の縁の濃紺",new Color(.11f,.20f,.24f),.35f);
        Shape("内側まである琺瑯洗面器",root,enamel,new[]{R(0,.108f,.108f),R(.007f,.115f,.115f),R(.085f,.167f,.167f),R(.089f,.165f,.165f),R(.085f,.160f,.160f),R(.013f,.108f,.108f),R(.010f,.001f,.001f)},48);
        var path=new Vector3[65];for(int i=0;i<=64;i++){float a=i*Mathf.PI*2/64;path[i]=V(Mathf.Cos(a)*.165f,.087f,Mathf.Sin(a)*.165f);}WestTube("洗面器の巻いた琺瑯縁",root,rim,path,.0027f);
        WestTowel(root,V(.012f,.055f,.015f),false);MergeSurfaces(root);return root;
    }
    void WestTowel(Transform root,Vector3 position,bool upright)
    {
        var towel=WestMaterial("使い込んだ生成りのタオル",new Color(.82f,.78f,.66f),.05f);towel.mainTexture=Resources.Load<Texture2D>("KinseiWestCast/TerryCotton");
        Transform fold=Oval("折り重ねたタオル",root,towel,position,upright?V(.062f,.10f,.034f):V(.112f,.033f,.063f));
        var stripe=WestMaterial("タオルの織り込んだ朱線",new Color(.47f,.16f,.095f),.07f);
        if(upright)Patch("湯籠のタオルの朱線",root,stripe,new[]{position+V(-.025f,-.09f,.032f),position+V(-.014f,-.09f,.035f),position+V(-.014f,.09f,.035f),position+V(-.025f,.09f,.032f)});
        else WestTube("洗面器のタオルの折り山",root,towel,new[]{position+V(-.10f,.025f,.025f),position+V(0,.032f,.027f),position+V(.10f,.022f,.027f)},.008f);
    }
    #if UNITY_EDITOR
    [Serializable] sealed class WestRimMetric
    {
        public string state;public float phase,thumbGapMm,fingerGapMm,thumbRadialMm,fingerRadialMm,anchorMm;public Vector3 thumbCorrection,fingerCorrection;public int thumbVertex,fingerVertex;
    }
    [Serializable] sealed class WestRimReport {public WestRimMetric[] samples;}
    public static void ProbeWestKiichiRim()
    {
        var o=new GameObject("Kiichi rim contact regression");o.hideFlags=HideFlags.HideAndDontSave;
        var actor=o.AddComponent<KinseiActor>();actor.Init("west-kiichi",0);
        var neutral=actor.leftHandRenderer.sharedMesh.vertices;
        var samples=new List<WestRimMetric>();var baked=new Mesh();
        for(int frame=0;frame<9;frame++)
        {
            bool walk=frame>0;actor.phase=(frame-1)/8f;actor.westCarrySway=walk?1:0;actor.Pose(walk?"walk":"idle",walk?1:0);
            actor.leftHandRenderer.BakeMesh(baked);var vertices=baked.vertices;
            var metric=new WestRimMetric{state=walk?"walk":"idle",phase=actor.phase,thumbGapMm=1000,fingerGapMm=1000};
            for(int i=0;i<vertices.Length;i++)
            {
                Vector3 p=neutral[i];float thumb=Ease(.020f,.035f,-p.x)*(1-Ease(-.003f,.006f,p.z))*Ease(.064f,.090f,-p.y);
                float finger=Ease(.074f,.092f,-p.y)*(1-thumb);
                bool t=thumb>.85f && p.y<-.09f,f=finger>.9f && p.y<-.095f;if(!t&&!f)continue;
                Vector3 world=actor.leftHandRenderer.transform.TransformPoint(vertices[i]);
                Vector3 local=actor.westLoad.InverseTransformPoint(world);
                float theta=Mathf.Atan2(local.z,local.x);
                Vector3 origin=actor.westLoad.TransformPoint(V(0,.087f,0));
                Vector3 ax=actor.westLoad.TransformVector(V(.165f,0,0)),az=actor.westLoad.TransformVector(V(0,0,.165f));
                for(int pass=0;pass<4;pass++)
                {
                    Vector3 q=origin+ax*Mathf.Cos(theta)+az*Mathf.Sin(theta),d=-ax*Mathf.Sin(theta)+az*Mathf.Cos(theta),dd=-ax*Mathf.Cos(theta)-az*Mathf.Sin(theta);
                    float denominator=Vector3.Dot(d,d)+Vector3.Dot(q-world,dd);if(Mathf.Abs(denominator)>.000001f)theta-=Vector3.Dot(q-world,d)/denominator;
                }
                Vector3 axis=origin+ax*Mathf.Cos(theta)+az*Mathf.Sin(theta);
                Vector3 radial=V(Mathf.Cos(theta),0,Mathf.Sin(theta));
                Vector3 section=local-V(radial.x*.165f,.087f,radial.z*.165f);
                float radius=actor.westLoad.TransformVector(section.normalized*.0027f).magnitude;
                float gap=(Vector3.Distance(world,axis)-radius)*1000;
                float side=(new Vector2(local.x,local.z).magnitude-.165f)*1000;
                if(t && gap<metric.thumbGapMm){metric.thumbGapMm=gap;metric.thumbRadialMm=side;metric.thumbVertex=i;metric.thumbCorrection=actor.lh.InverseTransformVector(axis+(world-axis).normalized*radius-world);}
                if(f && gap<metric.fingerGapMm){metric.fingerGapMm=gap;metric.fingerRadialMm=side;metric.fingerVertex=i;metric.fingerCorrection=actor.lh.InverseTransformVector(axis+(world-axis).normalized*radius-world);}
            }
            metric.anchorMm=Vector3.Distance(actor.lh.TransformPoint(WestRimContact),actor.westLoad.TransformPoint(actor.westGrip))*1000;
            samples.Add(metric);
        }
        string path=Path.GetFullPath(Path.Combine(Application.dataPath,"../../art-source/west-bath/cast/kiichi-rim-runtime-metrics.json"));
        File.WriteAllText(path,JsonUtility.ToJson(new WestRimReport{samples=samples.ToArray()},true));Debug.Log("WEST_RIM_PROBE "+path);
    }
    [Serializable] sealed class WestHandStudy {public Vector3[] vertices,normals,curl;public int[] triangles;}
    public static void ExportWestKiichiHand()
    {
        var o=new GameObject("Kiichi grip study");o.hideFlags=HideFlags.HideAndDontSave;
        var actor=o.AddComponent<KinseiActor>();actor.Init("west-kiichi",0);
        var mesh=actor.leftHandRenderer.sharedMesh;var delta=new Vector3[mesh.vertexCount];
        mesh.GetBlendShapeFrameVertices(0,0,delta,null,null);
        var study=new WestHandStudy{vertices=mesh.vertices,normals=mesh.normals,curl=delta,triangles=mesh.triangles};
        string path=Path.Combine(Application.dataPath,"../../art-source/west-bath/cast/kiichi-hand-study.json");
        File.WriteAllText(Path.GetFullPath(path),JsonUtility.ToJson(study));
        Debug.Log("WEST_HAND_STUDY "+Path.GetFullPath(path)+" vertices="+mesh.vertexCount);
    }
    #endif
    static void WestTube(string label,Transform parent,Material material,Vector3[] path,float radius)
    {
        const int sides=8;var v=new List<Vector3>();var uv=new List<Vector2>();var t=new List<int>();
        for(int i=0;i<path.Length;i++)
        {
            Vector3 along=(i==0?path[1]-path[0]:i==path.Length-1?path[i]-path[i-1]:path[i+1]-path[i-1]).normalized;
            Vector3 across=Vector3.Cross(along,Mathf.Abs(along.y)>.95f?Vector3.forward:Vector3.up).normalized,depth=Vector3.Cross(along,across).normalized;
            for(int j=0;j<sides;j++){float a=j*Mathf.PI*2/sides;v.Add(path[i]+radius*(across*Mathf.Cos(a)+depth*Mathf.Sin(a)));uv.Add(new Vector2((float)i/(path.Length-1),(float)j/sides));}
        }
        for(int i=0;i<path.Length-1;i++)for(int j=0;j<sides;j++){int a=i*sides+j,b=i*sides+(j+1)%sides,c=a+sides,d=b+sides;t.Add(a);t.Add(b);t.Add(c);t.Add(b);t.Add(d);t.Add(c);}
        var mesh=new Mesh{name=label};mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(t,0);mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();MeshObject(label,parent,material,mesh);
    }
}
