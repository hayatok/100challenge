using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiWorld
{
    Material railSeat,routePrint,ticketPrint,railWindow;
    Material[] carriageAdverts;
    readonly Light[] coachReadingLights=new Light[4];
    public void LightOccupiedCoach(int car)
    {
        for(int i=0;i<coachReadingLights.Length;i++)
            if(coachReadingLights[i])coachReadingLights[i].enabled=i/2==car;
    }
    Material RailPrint(string key,Material baseMaterial)
    {
        var texture=Resources.Load<Texture2D>("KinseiRail/"+key);
        if(!texture)return baseMaterial;
        return new Material(baseMaterial){name="宵待高架線 "+key,mainTexture=texture,color=Color.white};
    }

    void CarCollider(string label,Vector3 at,Vector3 size)
    {
        var part=new GameObject(label);part.transform.SetParent(train,false);part.transform.localPosition=at;
        part.AddComponent<BoxCollider>().size=size;
    }

    void BuildPassengerCar(List<Renderer> parts,int car,float x,Material ivory,Material red,Material steel,Material lamp)
    {
        if(!railSeat){
            railSeat=RailPrint("Moquette",velvet);routePrint=RailPrint("RouteBoard",cream);ticketPrint=RailPrint("Ticket",cream);
            carriageAdverts=PrintCells("CarAdvertisements",2,2);
            railWindow=new Material(Resources.Load<Shader>("KinseiRailGlass")){name="客室の薄い安全ガラス"};
        }
        void Panel(string name,float dx,float y,float z,float w,float h,float d,Material mat)
            =>CarPart(parts,name,new Vector3(x+dx,y,z),new Vector3(w,h,d),mat);
        Panel("Grooved saloon flooring",0,.19f,0,8.46f,.18f,2.28f,wood);
        CarCollider("Car floor",new Vector3(x,.19f,0),new Vector3(8.47f,.18f,2.31f));
        Panel("Arched enamel roof",0,2.86f,0,8.54f,.18f,2.38f,steel);
        Panel("Opal ceiling light",0,2.72f,0,5.5f,.07f,.16f,lamp);
        foreach(int side in new[]{-1,1}){
            float z=side*1.13f;
            Panel("Window head",0,2.49f,z,8.45f,.49f,.10f,ivory);
            for(int half=-1;half<=1;half+=2){
                float centre=side>0?half*2.54f:half*2.1f;
                float width=side>0?3.34f:4.21f;
                Panel("Apron",centre,.73f,z,width,.89f,.085f,ivory);
                Panel("Vermilion belt",centre,.94f,z+side*.052f,width,.13f,.035f,red);
                Panel("Saloon safety glass",centre,1.71f,z,width,1.09f,.014f,railWindow);
                CarCollider("Saloon window",new Vector3(x+centre,1.4f,z),new Vector3(width,2.25f,.08f));
                for(int w=0;w<3;w++)
                    Panel("Rubber window post",centre+(w-1)*1.10f,1.70f,z,.065f,1.13f,.095f,steel);
            }
        }
        foreach(int end in new[]{-1,1}){
            float dx=end*4.21f;
            Panel("Cab end",dx,.87f,0,.10f,1.16f,2.21f,ivory);
            Panel("End header",dx,2.45f,0,.105f,.72f,2.21f,ivory);
            int advert=car*2+(end>0?1:0);
            Panel("車内広告の亜鉛枠",dx-end*.061f,2.43f,0,.024f,.49f,1.22f,steel);
            var placard=Part("妻壁の地元広告",PrimitiveType.Quad,
                new Vector3(x+dx-end*.076f,2.43f,0),new Vector3(1.17f,.45f,1),carriageAdverts[advert],false,train);
            placard.transform.localRotation=Quaternion.Euler(0,end*90,0);
            Moving(placard);parts.Add(placard.GetComponent<Renderer>());
            CarCollider("Cab partition",new Vector3(x+dx,1.5f,0),new Vector3(.10f,2.6f,2.22f));
            Panel("Route indicator",dx+end*.065f,2.44f,0,.034f,.19f,.78f,lamp);
            Panel("Headlamp",dx+end*.065f,.99f,.78f,.05f,.19f,.21f,lamp);
            float doorOffset=end*.44f;
            var door=new GameObject("戸袋に引き込む乗降戸").transform;
            door.SetParent(train,false);railDoors[car*2+(end<0?0:1)]=door;
            Moving(Box("Lower enamel door",new Vector3(0,.81f,0),new Vector3(.88f,1.09f,.08f),ivory,true,door));
            Moving(Box("Door top rail",new Vector3(0,2.19f,0),new Vector3(.88f,.14f,.08f),ivory,false,door));
            Moving(Box("Door gasket",new Vector3(-end*.41f,1.77f,0),new Vector3(.045f,.85f,.08f),dark,false,door));
            door.localPosition=new Vector3(x+doorOffset,0,1.13f);
        }
        for(int seat=0;seat<6;seat++){
            float dx=(seat-2.5f)*1.23f;
            Panel("Seat plinth",dx,.46f,-.76f,1.17f,.33f,.53f,dark);
            Panel("Wool moquette bench",dx,.70f,-.73f,1.19f,.16f,.62f,railSeat);
            Panel("Upholstered backrest",dx,1.02f,-1.00f,1.18f,.55f,.15f,railSeat);
            Panel("Leather strap",dx,2.39f,-.46f,.042f,.37f,.026f,wood);
            Panel("Hanging grip top",dx,2.19f,-.46f,.18f,.029f,.030f,cream);
            Panel("Hanging grip bottom",dx,2.055f,-.46f,.18f,.029f,.030f,cream);
            for(int side=-1;side<=1;side+=2)Panel("Grip return",dx+.085f*side,2.12f,-.46f,.024f,.15f,.030f,cream);
        }
        CarCollider("Bench front",new Vector3(x,.63f,-.77f),new Vector3(7.48f,.68f,.61f));
        var lightObject=new GameObject("客室灯");lightObject.transform.SetParent(train,false);
        lightObject.transform.localPosition=new Vector3(x,2.51f,.10f);
        var light=lightObject.AddComponent<Light>();light.type=LightType.Point;light.range=5.6f;
        light.color=new Color(1,.79f,.52f);light.intensity=1.45f;light.renderMode=LightRenderMode.ForceVertex;
        for(int side=0;side<2;side++){
            float sign=side==0?-1:1;
            float u=1.32f*sign,z=.99f*sign;
            Panel("窓上の蛍光灯の反射笠",u,2.29f,z,.77f,.14f,.13f,ivory);
            Panel("乳白ガラスの横灯",u,2.27f,z-sign*.076f,.66f,.084f,.031f,lamp);
            var socket=new GameObject("窓上の横灯").transform;
            socket.SetParent(train,false);socket.localPosition=new Vector3(x+u,2.24f,z-sign*.145f);
            var reading=socket.gameObject.AddComponent<Light>();
            reading.type=LightType.Point;reading.range=4.6f;reading.intensity=2.2f;
            reading.color=new Color(1,.89f,.76f);reading.renderMode=LightRenderMode.ForcePixel;
            reading.shadows=LightShadows.None;reading.enabled=false;
            coachReadingLights[car*2+side]=reading;
        }
        Panel("Strap runner",0,2.58f,-.46f,7.7f,.05f,.05f,brass);
        var board=Part("Passenger route board",PrimitiveType.Quad,new Vector3(x+2.45f,2.46f,1.063f),new Vector3(1.08f,.23f,1),routePrint,false,train);
        Moving(board);
    }

    void BuildStation(int station,Material steel,Material ivory,Material concrete)
    {
        int sign=station==0?-1:1;
        float liftX=LiftX(station),stationX=StopX(station);
        float outside=stationX+sign*6.4f,inside=liftX-sign*.96f;
        float w=Mathf.Abs(outside-inside),cx=(outside+inside)*.5f;
        Box("Island side platform",new Vector3(cx,RailHeight-.13f,-21.43f),new Vector3(w,.26f,2.20f),concrete,true);
        Box("Brass platform edge",new Vector3(cx,RailHeight+.006f,-22.40f),new Vector3(w,.012f,.19f),brass);
        float fenceStart=liftX+sign*1.06f;
        Box("Platform parapet",new Vector3((fenceStart+outside)*.5f,RailHeight+.48f,-20.36f),
            new Vector3(Mathf.Abs(outside-fenceStart),.96f,.10f),steel,true);
        Box("End stop",new Vector3(outside,RailHeight+.50f,-21.43f),new Vector3(.095f,1,2.15f),steel,true);
        for(int i=0;i<3;i++)Box("Station pier",new Vector3(liftX+sign*(1.5f+i*6.1f),3.40f,-21.25f),new Vector3(.36f,6.8f,.47f),concrete);
        Box("Station enamel nameplate",new Vector3(stationX,8.65f,-20.35f),new Vector3(3.25f,.62f,.09f),ivory);
        Text(StopName(station),new Vector3(stationX,8.65f,-20.412f),.39f,dark,0);
        Box("Lift entrance sign",new Vector3(liftX,2.55f,-18.55f),new Vector3(2.18f,.44f,.075f),steel);
        Text(StopName(station)+"　のりば",new Vector3(liftX,2.55f,-18.49f),.20f,glow,180);
        for(int side=-1;side<=1;side+=2){
            float postX=liftX+side*1.03f;
            Box("Lift guide channel",new Vector3(postX,4.6f,-19.54f),new Vector3(.11f,9.2f,.12f),steel,true);
            Box("Lift guide foot",new Vector3(postX,.14f,-19.54f),new Vector3(.32f,.27f,.32f),concrete,true);
        }
        var lift=new GameObject(StopName(station)+"の昇降台").transform;lift.SetParent(transform,false);lifts[station]=lift;
        Moving(Box("Lift deck",new Vector3(0,-.07f,0),new Vector3(1.94f,.14f,1.88f),wood,true,lift));
        for(int side=-1;side<=1;side+=2)Moving(Box("Lift guard rail",new Vector3(side*.92f,.59f,0),new Vector3(.07f,1.18f,1.82f),steel,true,lift));
        Moving(Box("Up-down button housing",new Vector3(.84f,1.07f,.28f),new Vector3(.12f,.25f,.16f),brass,false,lift));
        Moving(Box("Illuminated travel button",new Vector3(.766f,1.08f,.28f),new Vector3(.045f,.085f,.085f),glow,false,lift));
        Box("Upper landing call button",new Vector3(liftX+sign*.91f,RailHeight+.94f,-20.48f),new Vector3(.13f,.23f,.13f),glow);
        var ticket=Part("Printed fare sample",PrimitiveType.Quad,new Vector3(liftX+.88f,1.53f,-19.26f),new Vector3(.24f,.12f,1),ticketPrint);
        ticket.transform.rotation=Quaternion.Euler(0,180,0);
    }
}
