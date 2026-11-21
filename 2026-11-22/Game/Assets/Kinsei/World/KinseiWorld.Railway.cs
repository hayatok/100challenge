using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiWorld
{
    Transform train;
    public const float RailHeight=6.90f, RailZ=-23.75f;
    public const float StationDwell=8.5f, RailTrip=11f;
    float trainClock;
    readonly Transform[] railDoors=new Transform[4], lifts=new Transform[2];
    readonly float[] liftGoals=new float[2];
    float doorTravel;
    public Transform Train => train;
    public Transform Lift(int station)=>lifts[station];
    public static float LiftX(int station)=>station==0?-8:8;
    public static float StopX(int station)=>station==0?-18:18;
    public static string StopName(int station)=>station==0?"宵待西口":"送像所前";
    public int RailStation => trainClock<StationDwell+RailTrip?0:1;
    float LegTime => trainClock%(StationDwell+RailTrip);
    public bool Stopped => LegTime<StationDwell;
    public int SecondsToBoard(int station)
    {
        if(station==RailStation && Docked)return 0;
        float start=station*(StationDwell+RailTrip)+.76f;
        return Mathf.CeilToInt(Mathf.Repeat(start-trainClock,2*(StationDwell+RailTrip)));
    }
    public bool Docked => LegTime<StationDwell && doorTravel>.97f;
    public int RailSeconds => Mathf.CeilToInt(LegTime<StationDwell?StationDwell-LegTime:StationDwell+RailTrip-LegTime);
    public bool AtLiftHeight(int station,float height)=>Mathf.Abs(lifts[station].position.y-height)<.005f;
    public void CallLift(int station,bool up)=>liftGoals[station]=up?RailHeight:0;

    void BuildRailway()
    {
        var concrete=Mat("Coal-stained pier concrete","#796F65",.03f,.25f);
        var strut=Mat("Riveted oxide-green railway steel","#536A69",.46f,.46f);
        var ivory=Mat("Interurban railway cream enamel","#D9C9A4",.35f,.65f);
        var coachRed=Mat("Interurban vermilion belt","#793A32",.30f,.54f);
        var saloon=Mat("Warm milk-glass carriage interior","#E7C191",.10f,.34f,.70f);
        const float track=-23.75f;
        Box("Elevated railway deck",new Vector3(0,6.28f,track),new Vector3(102,.32f,3.15f),concrete);
        for(int side=-1;side<=1;side+=2) {
            Box("Through girder",new Vector3(0,6.36f,track+side*1.51f),new Vector3(102,.51f,.12f),strut);
            Box("Guide rail",new Vector3(0,6.58f,track+side*.70f),new Vector3(102,.10f,.07f),dark);
        }
        for(int x=-48;x<=48;x+=8) {
            Box("Flared pier head",new Vector3(x,5.92f,track),new Vector3(1.7f,.45f,3.09f),concrete);
            Box("Bridge pier",new Vector3(x,2.96f,track),new Vector3(.70f,5.92f,.86f),concrete);
            Rail(new Vector3(x-2.12f,6.18f,track+1.38f),new Vector3(x,5.18f,track+1.38f),.072f,strut);
            Rail(new Vector3(x,5.18f,track+1.38f),new Vector3(x+2.12f,6.18f,track+1.38f),.072f,strut);
        }

        var blocks=Mat("Ceramic tile in evening shadow","#47515A",.13f,.36f);
        Finish(blocks,"rectangular_facade_tiles_02",new Vector2(3.5f,5f),.62f);
        var ledges=Mat("Weathered precast window hoods","#76818B",.08f,.34f);
        var blueGlass=Mat("Unlit office windows","#32424D",.46f,.67f);
        for(int i=0;i<11;i++) {
            float x=-50+i*10.1f,z=-37-(i*7%9);
            int floors=3+(i*5%4);
            Box("Walk-up rental block",new Vector3(x,floors*1.45f,z),new Vector3(8.6f,floors*2.9f,5),blocks);
            for(int floor=0;floor<floors;floor++) {
                float y=1.68f+2.9f*floor;
                Box("Recessed balcony edge",new Vector3(x,y-.78f,z+2.66f),new Vector3(8.62f,.14f,.41f),ledges);
                for(int column=0;column<4;column++)
                    Box("Apartment window",new Vector3(x-3+column*2,y,z+2.52f),new Vector3(1.45f,1.18f,.07f),
                        (floor*3+i+column*5)%7<2?saloon:blueGlass);
            }
            var tank=Cylinder("Rooftop gravity tank",new Vector3(x+2.4f,floors*2.9f+.68f,z),.70f,1.36f,ledges);
            Rail(tank.transform.localPosition+Vector3.up*.9f,tank.transform.localPosition+Vector3.up*1.9f,.027f,dark);
        }
        train=new GameObject("宵待高架線・二両編成").transform;
        train.SetParent(transform,false);
        var parts=new List<Renderer>();
        for(int car=0;car<2;car++) {
            float x=(car-.5f)*8.7f;
            BuildPassengerCar(parts,car,x,ivory,coachRed,strut,saloon);
        }
        for(int station=0;station<2;station++)BuildStation(station,strut,ivory,concrete);
        var surfaces=new Dictionary<Material,List<CombineInstance>>();
        foreach(var part in parts) {
            if(!surfaces.TryGetValue(part.sharedMaterial,out var meshes)){meshes=new List<CombineInstance>();surfaces.Add(part.sharedMaterial,meshes);}
            meshes.Add(new CombineInstance{mesh=part.GetComponent<MeshFilter>().sharedMesh,transform=train.worldToLocalMatrix*part.transform.localToWorldMatrix});
            part.enabled=false;
        }
        foreach(var group in surfaces) {
            var mesh=new Mesh{name="Rolling stock / "+group.Key.name,indexFormat=UnityEngine.Rendering.IndexFormat.UInt32};
            mesh.CombineMeshes(group.Value.ToArray());
            Surface(mesh.name,mesh,group.Key,train,false);
        }
        ResetRail();
    }

    void CarPart(List<Renderer> parts,string label,Vector3 at,Vector3 scale,Material finish)
    {
        if(!paddedMesh)paddedMesh=UpholsteryMesh();
        var go=Surface(label,paddedMesh,finish,train,false);
        go.transform.localPosition=at;go.transform.localScale=scale;
        parts.Add(go.GetComponent<Renderer>());
    }
    public void ResetRail()
    {
        trainClock=.8f;
        for(int i=0;i<2;i++){liftGoals[i]=0;lifts[i].localPosition=new Vector3(LiftX(i),0,-19.48f);}
        TickRail(0,false);
    }

    public void TickRail(float dt,bool inDoorway)
    {
        float leg=LegTime;
        if(!(inDoorway && leg>=StationDwell-1.05f && leg<StationDwell))
            trainClock=Mathf.Repeat(trainClock+dt,2*(StationDwell+RailTrip));
        leg=LegTime;
        float progress=Mathf.SmoothStep(0,1,Mathf.InverseLerp(StationDwell,StationDwell+RailTrip,leg));
        train.localPosition=new Vector3(Mathf.Lerp(StopX(RailStation),StopX(1-RailStation),progress),6.62f,RailZ);
        doorTravel=Mathf.Clamp01(Mathf.Min(leg/.76f,(StationDwell-leg)/.76f));
        for(int i=0;i<railDoors.Length;i++){
            float x=(i/2-.5f)*8.7f+(i%2==0?-1:1)*(.44f+.87f*doorTravel);
            railDoors[i].localPosition=new Vector3(x,0,1.13f);
        }
        for(int i=0;i<lifts.Length;i++){
            var at=lifts[i].localPosition;at.y=Mathf.MoveTowards(at.y,liftGoals[i],dt*1.85f);lifts[i].localPosition=at;
        }
    }
}
