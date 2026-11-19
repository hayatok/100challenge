using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool wingOpen;
        int wingStation;
        Texture2D floorPlan;
        int planDistrict=-1;

        internal void OpenWing(int station=-1)
        {
            if(!Field.WingActive && !Field.WingComplete)return;
            CloseFieldOverlay();
            wingStation=station<0?Mathf.Clamp(Field.WingRecommendedStation,0,5):Mathf.Clamp(station,0,5);
            wingOpen=true;
        }

        static Vector2 WingOnPlan(Rect plan,Vector3 p)
        {
            return new Vector2(plan.x+(p.x+16)*plan.width/32,plan.y+(152-p.z)*plan.height/63);
        }

        void PrepareFloorPlan()
        {
            int region=G.MissionIndex/2;
            if(floorPlan && planDistrict==region)return;
            if(floorPlan)Destroy(floorPlan);
            const int width=324,height=432;
            var pixels=new Color32[width*height];
            Color32 baseColor=new Color32(38,55,53,255),grid=new Color32(55,72,66,255);
            for(int y=0;y<height;y++)
                for(int x=0;x<width;x++)
                    pixels[y*width+x]=x%32==0 || y%32==0?grid:baseColor;
            foreach(var solid in RoomWingLayout.Solids(G.MissionIndex))
            {
                int x0=Mathf.Clamp(Mathf.FloorToInt((solid.x-solid.width*.5f+16)*width/32),0,width);
                int x1=Mathf.Clamp(Mathf.CeilToInt((solid.x+solid.width*.5f+16)*width/32),0,width);
                int z0=Mathf.Clamp(Mathf.FloorToInt((solid.z-solid.depth*.5f-89)*height/63),0,height);
                int z1=Mathf.Clamp(Mathf.CeilToInt((solid.z+solid.depth*.5f-89)*height/63),0,height);
                var color=solid.height>2.5f?new Color32(166,172,153,255):new Color32(86,98,88,255);
                for(int y=z0;y<z1;y++)for(int x=x0;x<x1;x++)pixels[y*width+x]=color;
            }
            floorPlan=new Texture2D(width,height,TextureFormat.RGBA32,false){name="Evacuation floor plan",filterMode=FilterMode.Bilinear};
            floorPlan.SetPixels32(pixels);floorPlan.Apply(false,true);planDistrict=region;
        }

        void DrawWing()
        {
            ModalBackdrop();
            Rect sheet=Dialog(788,472);
            float x=sheet.x+17,y=sheet.y,width=sheet.width-34;
            Text(R(x,y+10,width-130,23),G.DistrictName(G.MissionIndex)+"　／　館内見取図",16,Amber,true);
            Text(R(x,y+34,width-118,36),Field.WingTitle,26,Cream,true);
            if(Button(R(x+width-94,y+11,94,42),"閉じる",dark:true)){wingOpen=false;return;}
            Rect map=R(x,y+78,width*.42f,346);
            PrepareFloorPlan();
            GUI.DrawTexture(map,floorPlan);
            Outline(map,Edge);
            for(int side=0;side<2;side++)
            {
                var hinge=WingOnPlan(map,new Vector3(side==0?-3.5f:3.5f,0,120));
                if(!Field.WingRoomOpen(side))Fill(R(hinge.x-2,hinge.y-8,4,16),Rail);
            }
            for(int i=0;i<6;i++)
            {
                var position=WingOnPlan(map,Field.WingPosition(i));
                float bw=map.width*.43f;
                var label=R(position.x-bw*.5f,position.y-15,bw,36);
                if(Button(label,Field.WingRoomName(i),selected:i==wingStation,dark:true))wingStation=i;
                if(Field.WingStationDone(i))Fill(R(label.x+4,label.yMax-4,label.width-8,2),Green);
            }
            foreach(var unit in Field.Units)
            {
                if(unit.pos.z<90 || unit.pos.z>152 || Mathf.Abs(unit.pos.x)>16 || !unit.active || unit.boarded || (unit.kind!=UnitKind.Soldier && unit.id!=Field.WingResidentId))continue;
                var position=WingOnPlan(map,unit.pos);
                Fill(R(position.x-2,position.y-2,4,4),unit.kind==UnitKind.Soldier?Green:Amber);
            }
            Text(R(x,map.yMax+3,map.width,28),"南入口　↓　市街へ",15,Mist,true,TextAnchor.MiddleCenter);

            float right=map.xMax+18,cw=x+width-right;
            Text(R(right,y+77,cw,31),Field.WingRoomName(wingStation),23,Cream,true);
            Paragraph(R(right,y+112,cw,45),Field.WingCondition(wingStation),17,Amber);
            bool onFoot=G.Mode=="FPS";
            string hint=Field.WingStatus;
            if(onFoot && Field.WingAvailable(wingStation,0))
            {
                string needed=Field.WingDirectRequirement(wingStation,0);
                if(needed.Length>0)hint=needed;
            }
            Paragraph(R(right,y+157,cw,55),hint,16,Mist);
            if(!onFoot)
            {
                float sw=(cw-8)/3;
                for(int n=0;n<3;n++)
                {
                    int squad=n;
                    if(Button(R(right+n*(sw+4),y+216,sw,44),G.SquadName(n),enabled:HasSquad(n),selected:G.SelectedSquad==n,dark:true))
                        Submit(()=>G.SelectSquad(squad));
                }
            }
            else Text(R(right,y+215,cw,44),G.AtWingDesk==wingStation?G.SoldierName+"が現地にいます":"現地に着くと対応を選べます",17,Mist);
            for(int option=0;option<2;option++)
            {
                string action=Field.WingAction(wingStation,option);
                if(string.IsNullOrEmpty(action))continue;
                int choice=option,station=wingStation;
                bool enabled=Field.WingAvailable(station,choice) && (!onFoot || Field.WingDirectRequirement(station,choice).Length==0);
                if(Button(R(right,y+274+option*51,cw,45),action,primary:enabled && option==0,enabled:enabled,dark:true))
                    Submit(()=>{if(G.HandleWing(station,choice))wingOpen=false;});
            }
            if(Button(R(right,y+387,cw,44),onFoot?"案内を表示して戻る":"地図で位置を確認",dark:true))
                Submit(()=>{G.LocateWing(wingStation);wingOpen=false;});
        }
    }
}
