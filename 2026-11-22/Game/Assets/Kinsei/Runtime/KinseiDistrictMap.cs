using UnityEngine;
using UnityEngine.AI;

public sealed partial class KinseiSession
{
    // These extents cover the authored club and the walkable street bounds.
    // The pale surface below comes from the actual companion navigation mesh.
    static readonly Rect DistrictWorld=new Rect(-45,-21,68,31);
    Texture2D districtWalkable;
    readonly Vector2[] districtViewCorners=new Vector2[4];
    readonly Vector2[] districtGroundView=new Vector2[4];
    const int DistrictColumns=188,DistrictRows=86;
    bool DistrictMapVisible => command && !StageActive && !OnAir && shopView==ShopView.None;
    Rect DistrictMapRect(float w,float h) => new Rect(16,h-CommandDockHeight-16-124,200,124);
    Rect DistrictPlot(Rect frame) => new Rect(frame.x+6,frame.y+25,188,86);

    Vector2 DistrictPoint(Vector3 world,Rect plot) => new Vector2(
        plot.x+(world.x-DistrictWorld.xMin)/DistrictWorld.width*plot.width,
        plot.y+(DistrictWorld.yMax-world.z)/DistrictWorld.height*plot.height);
    bool DistrictContains(Vector3 world) => DistrictWorld.Contains(new Vector2(world.x,world.z));
    Rect DistrictFootprint(float x,float z,float width,float depth,Rect plot)
    {
        var nw=DistrictPoint(new Vector3(x-width*.5f,0,z+depth*.5f),plot);
        return new Rect(nw.x,nw.y,width/DistrictWorld.width*plot.width,depth/DistrictWorld.height*plot.height);
    }

    void BuildDistrictGeometry()
    {
        if(districtWalkable || walkways==null || !walkways.Ready)return;
        var mesh=NavMesh.CalculateTriangulation();
        if(mesh.indices.Length==0)return;
        var pixels=new bool[DistrictColumns*DistrictRows];
        Rect raster=new Rect(0,0,DistrictColumns,DistrictRows);
        float Cross(Vector2 a,Vector2 b,Vector2 c) => (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
        for(int n=0;n<mesh.indices.Length;n+=3){
            var va=mesh.vertices[mesh.indices[n]];var vb=mesh.vertices[mesh.indices[n+1]];var vc=mesh.vertices[mesh.indices[n+2]];
            // Omit elevated railway platforms. Retain the real upper conversation terrace.
            if(va.y>4 || vb.y>4 || vc.y>4)continue;
            var a=DistrictPoint(va,raster);var b=DistrictPoint(vb,raster);var c=DistrictPoint(vc,raster);
            float area=Cross(a,b,c);if(Mathf.Abs(area)<.001f)continue;
            int minX=Mathf.Max(0,Mathf.FloorToInt(Mathf.Min(a.x,Mathf.Min(b.x,c.x))));
            int maxX=Mathf.Min(DistrictColumns-1,Mathf.CeilToInt(Mathf.Max(a.x,Mathf.Max(b.x,c.x))));
            int minY=Mathf.Max(0,Mathf.FloorToInt(Mathf.Min(a.y,Mathf.Min(b.y,c.y))));
            int maxY=Mathf.Min(DistrictRows-1,Mathf.CeilToInt(Mathf.Max(a.y,Mathf.Max(b.y,c.y))));
            for(int y=minY;y<=maxY;y++)for(int x=minX;x<=maxX;x++){
                Vector2 q=new Vector2(x+.5f,y+.5f);
                if(Cross(a,b,q)*area>=0 && Cross(b,c,q)*area>=0 && Cross(c,a,q)*area>=0)pixels[y*DistrictColumns+x]=true;
            }
        }
        // Raster rows run north-to-south; Unity texture rows run bottom-to-top.
        // Upload once with an explicit Y flip, then overlay the alpha mask in one draw.
        var colors=new Color32[DistrictColumns*DistrictRows];
        Color32 pale=new Color(.72f,.79f,.76f,1);
        for(int y=0;y<DistrictRows;y++)for(int x=0;x<DistrictColumns;x++)
            if(pixels[y*DistrictColumns+x])colors[(DistrictRows-1-y)*DistrictColumns+x]=pale;
        districtWalkable=new Texture2D(DistrictColumns,DistrictRows,TextureFormat.RGBA32,false){
            name="District navigation ground",filterMode=FilterMode.Point,wrapMode=TextureWrapMode.Clamp,
            hideFlags=HideFlags.DontSave
        };
        districtWalkable.SetPixels32(colors);districtWalkable.Apply(false,true);
    }

    void DrawDistrictMap()
    {
        if(!DistrictMapVisible || cam==null)return;
        Rect frame=DistrictMapRect(hudW,hudH),plot=DistrictPlot(frame);
        Color blue=new Color(.13f,.23f,.28f),line=new Color(.44f,.58f,.60f);
        Block(frame,new Color(.055f,.10f,.13f,.98f));TacticalBorder(frame,line,1);
        Letter(new Rect(frame.x+8,frame.y+2,86,20),"宵待町",12,cream);
        Rect home=new Rect(frame.xMax-91,frame.y+2,84,20);
        Letter(home,"Home  真壁",11,gold,false,TextAnchor.MiddleRight);
        if(GUI.Button(home,GUIContent.none,GUIStyle.none)){
            FocusCommandAt(player.Position);
            Mark("district-map-home");
        }
        if(GUI.Button(plot,GUIContent.none,GUIStyle.none)){
            Vector2 at=Event.current.mousePosition;
            float x=DistrictWorld.xMin+(at.x-plot.x)/plot.width*DistrictWorld.width;
            float z=DistrictWorld.yMax-(at.y-plot.y)/plot.height*DistrictWorld.height;
            FocusCommandAt(new Vector3(x,0,z));
            Mark("district-map-pan");
        }
        if(Event.current.type!=EventType.Repaint)return;
        BuildDistrictGeometry();Block(plot,blue);
        // Real canal bed (World.StreetEnds), beneath the real bridge navmesh.
        Block(DistrictFootprint(-30.85f,-8.6f,5.9f,24,plot),new Color(.18f,.39f,.45f));
        // The club and the three shops use their actual authored floor dimensions.
        Color building=new Color(.29f,.40f,.43f);
        Block(DistrictFootprint(0,.5f,18,17,plot),building);
        for(int i=0;i<3;i++)Block(DistrictFootprint((i-1)*16,-17,9.2f,6,plot),building);
        if(districtWalkable){
            Color previous=GUI.color;GUI.color=Color.white;
            GUI.DrawTexture(plot,districtWalkable,ScaleMode.StretchToFill,true);
            GUI.color=previous;
        }
        Rect stage=DistrictFootprint(-5,4.4f,6,3.6f,plot);Block(stage,new Color(.68f,.53f,.28f));
        TacticalBorder(stage,new Color(.90f,.77f,.48f),1);
        // The four screen rays describe the visible ground, excluding the HUD.
        districtViewCorners[0]=new Vector2(0,60);districtViewCorners[1]=new Vector2(hudW,60);
        districtViewCorners[2]=new Vector2(hudW,hudH-CommandDockHeight);districtViewCorners[3]=new Vector2(0,hudH-CommandDockHeight);
        bool valid=true;var ground=new Plane(Vector3.up,0);
        for(int i=0;i<4;i++){
            var ray=cam.ViewportPointToRay(new Vector3(districtViewCorners[i].x/hudW,1-districtViewCorners[i].y/hudH,0));
            if(!ground.Raycast(ray,out float length)){valid=false;break;}
            districtGroundView[i]=DistrictPoint(ray.GetPoint(length),plot);
        }
        if(valid)for(int i=0;i<4;i++){
            Vector2 a=districtGroundView[i],b=districtGroundView[(i+1)%4];
            if(ClipChartLine(plot,ref a,ref b))HallStroke(a,b,new Color(.99f,.96f,.77f),1.5f);
        }
        void DrawPin(Vector3 world,Color tint,float size,bool outline=false){
            if(!DistrictContains(world))return;
            Vector2 at=DistrictPoint(world,plot);Rect r=new Rect(at.x-size*.5f,at.y-size*.5f,size,size);
            Block(new Rect(r.x-1,r.y-1,r.width+2,r.height+2),new Color(.04f,.08f,.10f));
            if(outline)TacticalBorder(r,tint,1);else Block(r,tint);
        }
        if(HallFrontsVisible)for(int slot=0;slot<2;slot++)DrawPin(HallFrontPosition(slot),FrontColor(slot),6,true);
        if(finale){
            Vector3 goal=finaleStep==FinaleStep.Cooperative?LotusDesk:finaleStep==FinaleStep.Exclusive?OpeningPost:RelaySeat;
            DrawPin(goal,gold,6,true);
        }
        foreach(var p in crew)if(!p.retired && p.hp>0)DrawPin(p.Position,mint,3);
        foreach(var g in guards)if(IsHallGuard(g) && g.hp>0 && !g.floorYielded)DrawPin(g.Position,red,3);
        if(player!=null)DrawPin(player.Position,gold,5);
        TacticalBorder(plot,line,1);
    }
}
