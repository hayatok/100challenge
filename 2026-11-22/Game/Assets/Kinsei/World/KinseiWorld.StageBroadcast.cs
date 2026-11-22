using System.Collections.Generic;
using System.IO;
using UnityEngine;

public sealed partial class KinseiWorld
{
    readonly List<Object> stageSignAssets=new List<Object>();
    Material stageRimGlass,stageLipGlass,deskCallGlass,deskScope;
    bool stageBroadcastLive;

    Material StageFinish(string name,string tint,float metal,float smooth,float emission=0)
    {
        var material=Mat(name,tint,metal,smooth,emission);
        stageSignAssets.Add(material);return material;
    }

    void BuildStageSign()
    {
        var leaves=StageFinish("金星・花彫りの真鍮扇","#F3DCC0",.35f,.36f,.20f);
        leaves.mainTexture=Resources.Load<Texture2D>("KinseiStageBroadcast/EtchedLeaves");
        leaves.SetTexture("_EmissionMap",leaves.mainTexture);
        var bronze=StageFinish("金星・古美の側板","#6B5141",.55f,.39f);
        var edge=StageFinish("金星・磨き縁","#CDA66B",.66f,.53f,.09f);
        var letters=StageFinish("金星・浮出し金文字","#FFE1A0",.38f,.54f,.69f);
        var drapes=StageFinish("金星・朱の袖幕","#9D3A39",.035f,.22f);
        Finish(drapes,"velour_velvet",new Vector2(2.2f,2.5f),.29f);
        stageRimGlass=StageFinish("金星・扇の乳白球","#FFE8B8",.08f,.49f,1);
        stageLipGlass=StageFinish("金星・框の足元灯","#FFE7BA",.07f,.47f,1);
        var finishes=new Dictionary<string,Material>{
            {"leaves",leaves},{"bronze",bronze},{"metal",edge},{"letters",letters},
            {"velvet",drapes},{"glass",stageRimGlass},{"apron",stageLipGlass}
        };
        ReadStageParts("KinseiStageBroadcast/StageSign",(key,mesh)=>Surface(mesh.name,mesh,finishes[key],transform));
    }

    void ReadStageParts(string path,System.Action<string,Mesh> install)
    {
        var model=Resources.Load<TextAsset>(path);
        using(var reader=new BinaryReader(new MemoryStream(model.bytes))){
            if(reader.ReadUInt32()!=0x3147534b)throw new InvalidDataException("金星の舞台看板の形式が違います");
            int count=reader.ReadInt32();
            for(int group=0;group<count;group++){
                string key=reader.ReadString();
                int vertexCount=reader.ReadInt32(),indexCount=reader.ReadInt32();
                var vertices=new Vector3[vertexCount];var normals=new Vector3[vertexCount];var uv=new Vector2[vertexCount];
                for(int i=0;i<vertexCount;i++){
                    vertices[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());
                    normals[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());
                    uv[i]=new Vector2(reader.ReadSingle(),reader.ReadSingle());
                }
                var indices=new int[indexCount];
                for(int i=0;i<indices.Length;i++)indices[i]=reader.ReadInt32();
                var mesh=new Mesh{name=model.name+"・"+key,vertices=vertices,normals=normals,uv=uv,triangles=indices};
                mesh.RecalculateTangents();mesh.RecalculateBounds();stageSignAssets.Add(mesh);
                install(key,mesh);
            }
        }
    }

    Transform stagePanel,stageLevelPointer;
    public void SetStageLevel(float amount)
    {
        if(stageLevelPointer)
            stageLevelPointer.localRotation=Quaternion.AngleAxis(Mathf.Lerp(25,-43,amount),Vector3.forward);
    }

    public void StageLevelGrip(out Vector3 point,out Vector3 normal,out Vector3 fingers)
    {
        // Centre of the raised 9 mm index tab; its flanks sit between the two fingertip pads.
        point=stageLevelPointer.TransformPoint(new Vector3(0,.012f,.020f));
        normal=stageLevelPointer.right;
        fingers=-stageLevelPointer.forward;
    }

    Texture standbyScope;

    public void SetStageMonitor(Texture picture)
    {
        if(!deskScope)return;
        var signal=picture?picture:standbyScope;
        deskScope.mainTexture=signal;
        deskScope.SetTexture("_EmissionMap",signal);
    }

    public void ViewStageMonitor(out Vector3 eye,out Vector3 focus)
    {
        // From the free edge of the desk: the clerk works along its local +Z axis.
        focus=stagePanel.TransformPoint(new Vector3(-.071f,.008f,.110f));
        eye=stagePanel.TransformPoint(new Vector3(-.249f,.104f,.53f));
    }

    public void ViewStageFader(out Vector3 eye,out Vector3 focus)
    {
        focus=stagePanel.TransformPoint(new Vector3(.145f,.006f,.120f));
        eye=stagePanel.TransformPoint(new Vector3(.335f,.170f,.432f));
    }

    void BuildBroadcastDesk()
    {
        var desk=new GameObject("舞台の実況卓").transform;desk.SetParent(transform,false);
        desk.localPosition=new Vector3(-1.90f,0,1.05f);
        // The operator stands at (-1.35,0,.70), looking into the sloped panel.
        desk.localRotation=Quaternion.LookRotation(new Vector3(.55f,0,-.35f));
        Cushion("実況卓の木口",new Vector3(0,.86f,0),new Vector3(.72f,.060f,.40f),wood,desk,true);
        for(int s=-1;s<=1;s+=2)
            Box("実況卓の鋼製脚",new Vector3(s*.27f,.425f,.01f),new Vector3(.042f,.83f,.27f),dark,false,desk);
        Box("実況卓の貫",new Vector3(0,.22f,-.07f),new Vector3(.55f,.045f,.034f),brass,false,desk);
        var panel=new GameObject("実況器の傾斜盤").transform;panel.SetParent(desk,false);
        stagePanel=panel;
        panel.localPosition=new Vector3(0,.973f,-.02f);panel.localRotation=Quaternion.Euler(-18,0,0);
        deskScope=StageFinish("実況卓の監視管","#43544F",.11f,.43f,1);
        var chart=Resources.Load<Texture2D>("KinseiDistrictArt/relay-test");
        standbyScope=chart;SetStageMonitor(null);
        if(!tubeGlass)tubeGlass=ScreenGlass();
        var scope=Surface("実況卓の監視管面",tubeGlass,deskScope,panel);
        scope.transform.localPosition=new Vector3(-.104f,.005f,.112f);
        scope.transform.localRotation=Quaternion.Euler(0,180,0);scope.transform.localScale=new Vector3(.365f,.314f,.22f);
        stageLevelPointer=new GameObject("送出レベルの回転軸").transform;
        stageLevelPointer.SetParent(panel,false);
        stageLevelPointer.localPosition=new Vector3(.179f,-.018f,.108f);
        BuildConsoleParts(panel);
        SetStageLevel(0);
        Cylinder("呼出球の真鍮口金",new Vector3(.213f,.098f,-.015f),.034f,.036f,brass,false,panel);
        deskCallGlass=StageFinish("実況卓の赤い呼出球","#A64735",.05f,.42f,1);
        Part("実況卓の呼出ガラス",PrimitiveType.Sphere,new Vector3(.213f,.129f,-.015f),new Vector3(.056f,.066f,.056f),deskCallGlass,false,panel);
        SetStageBroadcast(stageBroadcastLive);
    }

    void BuildConsoleParts(Transform panel)
    {
        var atlas=Resources.Load<Texture2D>("KinseiBroadcastConsole/Finish");
        var enamel=StageFinish("実況卓・焼付黒琺瑯","#FFFFFF",.16f,.39f);
        var turned=StageFinish("実況卓・旋削黄銅","#EFE4C8",.52f,.44f);
        enamel.mainTexture=atlas;
        turned.mainTexture=atlas;
        var steel=StageFinish("実況卓・皿ねじ","#9B9285",.69f,.42f);
        var rim=StageFinish("実況卓・古美の真鍮枠","#9B794C",.61f,.47f);
        var gasket=StageFinish("実況卓・管面パッキン","#352F2A",.03f,.29f);
        var glassEdge=StageFinish("実況卓・管面の磨き縁","#728581",.39f,.57f);
        var finishes=new Dictionary<string,Material>{
            {"case",enamel},{"gain",turned},{"level",turned},{"ivory",cream},
            {"steel",steel},{"trim",rim},{"gasket",gasket},{"glasslip",glassEdge}
        };
        ReadStageParts("KinseiBroadcastConsole/Console",(key,mesh)=>{
            bool rotates=key=="level" || key=="ivory";
            Surface(mesh.name,mesh,finishes[key],rotates?stageLevelPointer:panel,!rotates);
        });
    }

    public void SetStageBroadcast(bool live)
    {
        stageBroadcastLive=live;
        if(!deskCallGlass)return;
        stageRimGlass.SetColor("_EmissionColor",live?new Color(1.48f,.94f,.43f):new Color(.53f,.34f,.18f));
        stageLipGlass.SetColor("_EmissionColor",live?new Color(1.02f,.68f,.38f):new Color(.47f,.32f,.19f));
        deskCallGlass.SetColor("_EmissionColor",live?new Color(1.45f,.18f,.06f):Color.black);
        deskScope.SetColor("_EmissionColor",live?new Color(.67f,.81f,.68f):new Color(.014f,.023f,.018f));
    }

    void ReleaseStageSign()
    {
        foreach(var asset in stageSignAssets)if(asset)Destroy(asset);
        stageSignAssets.Clear();
    }
}
