using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiSession
{
    struct MapOrder
    {
        public Vector3 spot;
        public Rect tag;
        public string caption;
        public string place;
        public Duty duty;
        public bool desk;
        public bool disabled;
    }
    readonly List<MapOrder> mapOrders = new();
    readonly List<Rect> mapOrderExclusions = new();
    bool mapOpened;
    int previousMapArea;
    bool mapSelecting,mapSelectionMoved,mapSelectionExtend;
    Vector2 mapSelectionStart,mapSelectionEnd;
    int mapSelectionBase;

    void CancelMapSelection(){mapSelecting=false;mapSelectionMoved=false;}

    Rect MapSelectionRect => Rect.MinMaxRect(Mathf.Min(mapSelectionStart.x,mapSelectionEnd.x),Mathf.Min(mapSelectionStart.y,mapSelectionEnd.y),Mathf.Max(mapSelectionStart.x,mapSelectionEnd.x),Mathf.Max(mapSelectionStart.y,mapSelectionEnd.y));

    int MapSelectionMembers()
    {
        int mask=0;Rect area=MapSelectionRect;
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        float w=Screen.width/scale,h=Screen.height/scale;
        for(int i=0;i<crew.Count;i++){
            var p=crew[i];if(p.hp<=0 || p.retired)continue;
            if(!TacticalPoint(p.Position+Vector3.up*.25f,w,h,out var gui) || CommandDeskHits(gui,w,h))continue;
            Vector2 pixels=new Vector2(gui.x*scale,Screen.height-gui.y*scale);
            if(area.Contains(pixels))mask|=1<<i;
        }
        return mask;
    }

    bool UpdateMapSelection()
    {
        if(!mapSelecting)return false;
        if(!command || paused || !Application.isFocused || Input.GetMouseButtonDown(1)){CancelMapSelection();return false;}
        mapSelectionEnd=Input.mousePosition;
        float threshold=6*Mathf.Min(Screen.width/1100f,Screen.height/720f);
        if((mapSelectionEnd-mapSelectionStart).sqrMagnitude>threshold*threshold)mapSelectionMoved=true;
        if(Input.GetMouseButtonUp(0)){
            if(mapSelectionMoved)SetSelection(MapSelectionMembers() | (mapSelectionExtend?LivingMembers(mapSelectionBase):0));
            else if(!OverHUD()){
                float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
                var mouse=new Vector2(mapSelectionEnd.x,Screen.height-mapSelectionEnd.y)/scale;
                int member=TacticalCrewAt(mouse,Screen.width/scale,Screen.height/scale);
                if(member>=0)SelectMember(member,mapSelectionExtend);
            }
            CancelMapSelection();return true;
        }
        if(!Input.GetMouseButton(0)){CancelMapSelection();return false;}
        return true;
    }

    void FrameMapOrders()
    {
        CancelMapSelection();
        mapOrders.Clear();
        if(!command)return;
        if(StageActive){mapOffset=new Vector2(-3.5f,.45f);Motion(player,"guard");return;}
        int area=HallFrontsVisible?1:WestNearby?2:finale?3:0;
        if(mapOpened && previousMapArea==area)return;
        mapOpened=true;previousMapArea=area;
        if(HallFrontsVisible){
            // A player coming in from the street should see both dispatch sites,
            // even after inspecting the distant shops on the previous map.
            chartSize=11f;
            mapOffset=new Vector2(-.6f,-1.65f);
            return;
        }
        // Put the entrance above the crew panel while retaining the stage in view.
        bool atClub=!finale && player.Position.x>=-12 && player.Position.x<=9 && player.Position.z>=-14;
        float focusZ=atClub?-8f:player.Position.z;
        float focusX=atClub?-2:player.Position.x;
        mapOffset=new Vector2(Mathf.Clamp(focusX,-43,19),Mathf.Clamp(focusZ-(HallFrontsVisible?-1.05f:1.55f),-20.5f,4.5f));
        if(atClub)chartSize=12.8f;
    }

    void BuildMapOrders(float w,float h)
    {
        mapOrders.Clear();
        if(!command || cam==null || OnAir || (StageActive && StageSpeaking) || shopView!=ShopView.None)return;
        float bottom=h-CommandDockHeight-8;
        int mask=SelectedMembers,count=CountMembers(mask);
        Person selected=count==1?crew[FirstMember(mask)]:null;
        mapOrderExclusions.Clear();
        if(HallFrontsVisible)for(int slot=0;slot<2;slot++)
            if(!HallFrontReady(1-slot) && HallMapTag(slot,w,h,out var site,out _))mapOrderExclusions.Add(site);
        // Reserve the actual projected crew markers, rebuilt after every pan/zoom.
        foreach(var person in everyone){
            if(person.retired || person.hp<=0)continue;
            if(TacticalPoint(person.Position+Vector3.up*.25f,w,h,out var marker))
                mapOrderExclusions.Add(new Rect(marker.x-21,marker.y-21,42,42));
        }
        void Add(Vector3 spot,string caption,Duty duty,bool desk=false,bool disabled=false)
        {
            if(count==0){caption="組員を選ぶ："+caption;disabled=true;}
            else if(count>1 && (desk || !GroupOrder(duty)) && !(WestCanOrder && duty==Duty.Attend && count==2)){
                caption=(desk?"実況卓":duty==Duty.StageWitness?"舞台袖":duty==Duty.Backstage?"楽屋口":duty==Duty.BoxOffice?"帳場":!finale && !WestCanOrder?"梶の席・辰":"担当")+"：一人を選ぶ";disabled=true;
            }
            if(desk && selected!=null && (selected==stageWitness || selected.duty==Duty.Attend || selected.duty==Duty.Backstage || selected.duty==Duty.BoxOffice)){
                caption="実況卓：別の組員を選ぶ";disabled=true;
            }
            if(!TacticalPoint(spot+Vector3.up*.2f,w,h,out var at))return;
            string place=desk?"実況卓":duty==Duty.Follow?"真壁":duty==Duty.Rest?"休息所":
                duty==Duty.BoxOffice?"帳場":duty==Duty.StageWitness?"舞台袖":duty==Duty.Backstage?"楽屋口":
                finale?(finaleStep==FinaleStep.Connect?"送像所":finaleStep==FinaleStep.Cooperative?"客席":"開場口"):
                WestCanOrder?"浴場前":"梶の席";
            // Compact destinations stay next to their real floor point. Never scatter
            // a long instruction across the map to find an unrelated empty area.
            Rect tag=new Rect(at.x-29,at.y-22,58,54);
            float best=float.PositiveInfinity;Rect chosen=tag;
            // Try nearby rows as well as columns. Captions must stay clear of the
            // mission panel and minimap as the camera moves around the district.
            for(int row=-1;row<=1;row++)for(int col=-3;col<=3;col++){
                float dx=col*32,dy=row*56;
                var candidate=new Rect(Mathf.Clamp(tag.x+dx,6,w-64),Mathf.Clamp(tag.y+dy,60,bottom-54),58,54);
                float score=Vector2.Distance(candidate.center,tag.center);
                if(CommandDeskCovers(candidate,w,h))score+=10000;
                foreach(var previous in mapOrders)if(previous.tag.Overlaps(candidate))score+=1000;
                foreach(var exclusion in mapOrderExclusions)if(exclusion.Overlaps(candidate))score+=500;
                if(score<best){best=score;chosen=candidate;}
            }
            if(CommandDeskCovers(chosen,w,h))return;
            mapOrders.Add(new MapOrder{spot=spot,tag=chosen,caption=caption,place=place,duty=duty,desk=desk,disabled=disabled});
        }

        if(StageActive){
            if(stageBeat!=StageBeat.Settled)Add(StageDeskPost,selected!=null && selected==stageDeskRunner?"実況の担当を外す":"実況卓を任せる",Duty.Go,true);
            return;
        }
        Add(player.Position,"真壁へ呼び戻す",Duty.Follow);
        Add(new Vector3(0,0,-9.6f),"表で休息",Duty.Rest);
        if(finale){
            if(finaleStep==FinaleStep.Connect)Add(RelaySeat,"送像所をつなぐ",Duty.Attend);
            if(finaleStep==FinaleStep.Cooperative)Add(LotusDesk,"客席を任せる",Duty.Attend);
            if(finaleStep==FinaleStep.Exclusive)Add(OpeningPost,"開場を任せる",Duty.Attend);
            return;
        }
        if(!HouseClaimed && (phase==Phase.Arrival || phase==Phase.Floor || phase==Phase.Choice))
            Add(KinseiBoxOffice.Counter,"帳場の伝票",Duty.BoxOffice);
        if(CanOrderStageWitness)Add(StageWing,selected!=null && selected==stageWitness?"舞台の立会を解く":"舞台袖で立ち会う",Duty.StageWitness);
        if(CanOrderBackstage)Add(BackstagePost,selected!=null && selected.duty==Duty.Backstage?"楽屋口から戻す":"楽屋口の札",Duty.Backstage);
        if(!accord && !WestCanOrder && (phase==Phase.Arrival || phase==Phase.Floor))
            Add(table,selected==crew[0]?"梶の席へ辰を送る":"梶の席：辰を一人選ぶ",Duty.Attend,disabled:selected!=crew[0]);
        if(WestCanOrder)Add(SeoDoor,"客を迎えに行く",Duty.Attend);
    }

    bool MapOrderInput()
    {
        if(inspectingStageLevel){CancelMapSelection();return false;}
        if(UpdateMapSelection())return true;
        if(Input.GetKeyDown(KeyCode.Home))FocusCommandAt(player.Position);
        bool left=Input.GetMouseButtonDown(0),right=Input.GetMouseButtonDown(1);
        if((!left && !right) || OverHUD())return false;
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        Vector2 mouse=new Vector2(Input.mousePosition.x,Screen.height-Input.mousePosition.y)/scale;
        // People are painted above destinations. Honour their visible marker
        // before nearby task hit areas, with the same projection after a pan.
        Person guard=TacticalGuardAt(mouse,Screen.width/scale,Screen.height/scale,true);
        if(right && !StageActive && guard!=null){DesignateGuard(guard);return true;}
        if(left && TacticalCrewAt(mouse,Screen.width/scale,Screen.height/scale,true)>=0){
            BeginMapSelection();return true;
        }
        for(int i=mapOrders.Count-1;i>=0;i--){
            var visible=mapOrders[i];
            if(!visible.tag.Contains(mouse))continue;
            // Use the displayed hit area, but check the job against the current selection and phase.
            BuildMapOrders(Screen.width/scale,Screen.height/scale);
            foreach(var order in mapOrders){
                if(order.duty!=visible.duty || order.desk!=visible.desk || order.spot!=visible.spot)continue;
                if(order.disabled)Say(order.caption);
                else if(order.desk)OrderStageDesk();
                else Assign(order.duty);
                break;
            }
            return true;
        }
        if(HallFrontsVisible){int front=HallPinAt(Input.mousePosition);if(front>=0){AssignHallFront(front);return true;}}
        TacticalGuardAt(mouse,Screen.width/scale,Screen.height/scale);
        if(right && !StageActive && GuardAtScreen(Input.mousePosition)!=null)return false;
        if(right && !StageActive && TacticalPoint(player.Position+Vector3.up*.25f,Screen.width/scale,Screen.height/scale,out var playerAt)
            && TacticalPersonHit(playerAt).Contains(mouse)){Assign(Duty.Follow);return true;}
        if(left){BeginMapSelection();return true;}
        return false;
    }

    void BeginMapSelection()
    {
        mapSelecting=true;mapSelectionMoved=false;
        mapSelectionStart=mapSelectionEnd=Input.mousePosition;
        mapSelectionExtend=Input.GetKey(KeyCode.LeftShift)||Input.GetKey(KeyCode.RightShift);
        mapSelectionBase=SelectedMembers;
    }

    void DrawMapOrders()
    {
        if(!command || Event.current.type!=EventType.Repaint)return;
        BuildMapOrders(hudW,hudH);
        foreach(var order in mapOrders){
            var pt=cam.WorldToViewportPoint(order.spot+Vector3.up*.2f);
            Vector2 at=new(pt.x*hudW,(1-pt.y)*hudH);
            bool hover=order.tag.Contains(Event.current.mousePosition);
            Color tint=order.disabled?brass:mint;
            if(Vector2.Distance(at,order.tag.center)>34)HallStroke(at,order.tag.center,new Color(tint.r,tint.g,tint.b,.48f),1);
            Rect icon=new Rect(order.tag.center.x-16,order.tag.y,32,32);
            Block(icon,hover?new Color(.18f,.32f,.30f,.98f):ink);
            TacticalBorder(icon,tint,hover?2:1);
            TacticalOrderIcon(icon,order.duty,order.desk,tint);
            Rect label=new Rect(order.tag.x-4,order.tag.y+33,order.tag.width+8,19);
            Block(label,ink);Letter(label,order.place,12,cream,false,TextAnchor.MiddleCenter);
            if(hover){
                float width=Mathf.Min(380,Mathf.Max(150,order.caption.Length*13+22));
                Rect tip=new Rect(Mathf.Clamp(order.tag.center.x-width*.5f,8,hudW-width-8),Mathf.Clamp(order.tag.y-31,60,hudH-CommandDockHeight-30),width,26);
                Block(tip,ink);TacticalBorder(tip,tint,1);Letter(tip,order.caption,13,cream,false,TextAnchor.MiddleCenter);
            }
        }

        if(mapSelecting && mapSelectionMoved){
            float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
            Rect pixels=MapSelectionRect;
            Rect box=new(pixels.x/scale,(Screen.height-pixels.yMax)/scale,pixels.width/scale,pixels.height/scale);
            Block(box,new Color(.43f,.88f,.81f,.08f));
            Block(new Rect(box.x,box.y,box.width,1),mint);Block(new Rect(box.x,box.yMax-1,box.width,1),mint);
            Block(new Rect(box.x,box.y,1,box.height),mint);Block(new Rect(box.xMax-1,box.y,1,box.height),mint);
            int preview=MapSelectionMembers();
            for(int i=0;i<crew.Count;i++)if((preview&(1<<i))!=0){
                var at=cam.WorldToScreenPoint(crew[i].Position+Vector3.up*.25f);
                Rect mark=new(at.x/scale-12,(Screen.height-at.y)/scale-12,24,24);
                Block(mark,ink);Letter(mark,(i+1).ToString(),16,mint,true,TextAnchor.MiddleCenter);
            }
            Rect caption=new(Mathf.Clamp(box.x,8,hudW-145),Mathf.Clamp(box.y-27,82,hudH-CommandDockHeight-30),137,25);
            Block(caption,ink);Letter(caption,CountMembers(preview)+"人を選択"+(mapSelectionExtend?"・追加":""),13,mint,false,TextAnchor.MiddleCenter);
        }
    }
}
