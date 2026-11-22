using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiSession
{
    struct MapOrder
    {
        public Vector3 spot;
        public Rect tag;
        public string caption;
        public Duty duty;
        public bool desk;
        public bool disabled;
    }
    readonly List<MapOrder> mapOrders = new();
    readonly List<Rect> mapOrderExclusions = new();
    // Choose clear label positions when the map opens. Passing crew should not move a button under the pointer.
    readonly List<Vector3> mapOpeningHeads = new();
    bool mapOpened;
    bool mapSelecting,mapSelectionMoved,mapSelectionExtend;
    Vector2 mapSelectionStart,mapSelectionEnd;
    int mapSelectionBase;

    void CancelMapSelection(){mapSelecting=false;mapSelectionMoved=false;}

    Rect MapSelectionRect => Rect.MinMaxRect(Mathf.Min(mapSelectionStart.x,mapSelectionEnd.x),Mathf.Min(mapSelectionStart.y,mapSelectionEnd.y),Mathf.Max(mapSelectionStart.x,mapSelectionEnd.x),Mathf.Max(mapSelectionStart.y,mapSelectionEnd.y));

    int MapSelectionMembers()
    {
        int mask=0;Rect area=MapSelectionRect;
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        float bottom=(HallFrontsVisible?HallCommandHeight:CommandPanelHeight)*scale;
        for(int i=0;i<crew.Count;i++){
            var p=crew[i];if(p.hp<=0 || p.retired)continue;
            var at=cam.WorldToScreenPoint(p.Position+Vector3.up);
            if(at.z>0 && at.x>=0 && at.x<=Screen.width && at.y>bottom && at.y<Screen.height-82*scale && area.Contains(at))mask|=1<<i;
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
                float nearest=Screen.height*.057f;int member=-1;
                for(int i=0;i<crew.Count;i++){
                    if(crew[i].hp<=0 || crew[i].retired)continue;
                    var at=cam.WorldToScreenPoint(crew[i].Position+Vector3.up);
                    float distance=Vector2.Distance(mapSelectionEnd,at);
                    if(at.z>0 && distance<nearest){nearest=distance;member=i;}
                }
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
        mapOpeningHeads.Clear();
        if(!command)return;
        foreach(var person in everyone){
            if(!person.retired && person.hp>0 && (person==player || crew.Contains(person) || IsHallGuard(person)))
                mapOpeningHeads.Add(person.Position+Vector3.up*1.6f);
        }
        if(StageActive){mapOffset=new Vector2(-3.5f,.45f);Motion(player,"guard");return;}
        if(mapOpened)return;
        mapOpened=true;
        // Put the entrance above the crew panel while retaining the stage in view.
        bool atClub=!finale && player.Position.x>=-12 && player.Position.x<=9 && player.Position.z>=-14;
        float focusZ=atClub?-5.5f:player.Position.z;
        float focusX=atClub?-2:player.Position.x;
        mapOffset=new Vector2(Mathf.Clamp(focusX,-43,19),Mathf.Clamp(focusZ-(HallFrontsVisible?-1.05f:1.55f),-20.5f,4.5f));
        if(atClub)chartSize=12.8f;
    }

    void BuildMapOrders(float w,float h)
    {
        mapOrders.Clear();
        if(!command || cam==null || OnAir || (StageActive && StageSpeaking) || shopView!=ShopView.None)return;
        float bottom=h-(HallFrontsVisible?HallCommandHeight:CommandPanelHeight)-8;
        int mask=SelectedMembers,count=CountMembers(mask);
        Person selected=count==1?crew[FirstMember(mask)]:null;
        mapOrderExclusions.Clear();
        if(!HallFrontsVisible){
            if(!StageActive)mapOrderExclusions.Add(new Rect(22,showFps?112:86,510,29));
            if(showFps)mapOrderExclusions.Add(new Rect(22,78,90,28));
            if(phase==Phase.Choice && escapeTime>0)mapOrderExclusions.Add(new Rect(w-182,85,160,34));
        }
        if(HallFrontsVisible)for(int slot=0;slot<2;slot++)
            if(!HallFrontReady(1-slot) && HallMapTag(slot,w,h,out var hall,out _))mapOrderExclusions.Add(hall);
        foreach(var position in mapOpeningHeads){
            var head=cam.WorldToViewportPoint(position);
            if(head.z>0 && head.x>=0 && head.x<=1 && head.y>=0 && head.y<=1)
                mapOrderExclusions.Add(new Rect(head.x*w-35,(1-head.y)*h-28,70,55));
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
            var pt=cam.WorldToViewportPoint(spot+Vector3.up*.4f);
            Vector2 at=new(pt.x*w,(1-pt.y)*h);
            // A floor point may sit behind the crew panel while its task label
            // still belongs above that panel (notably the rest point at the door).
            if(pt.z<=0 || at.x<12 || at.x>w-12 || at.y<86 || at.y>h-8)return;
            float width=Mathf.Max(100,caption.Length*14+20);
            Rect tag=new(Mathf.Clamp(at.x-width*.5f,8,w-width-8),at.y+16,width,34);
            bool Fits(Rect candidate)
            {
                if(candidate.x<8 || candidate.xMax>w-8 || candidate.y<82 || candidate.yMax>bottom)return false;
                foreach(var previous in mapOrders)if(previous.tag.Overlaps(candidate))return false;
                foreach(var exclusion in mapOrderExclusions)if(exclusion.Overlaps(candidate))return false;
                return true;
            }
            void Place(Rect candidate) => mapOrders.Add(new MapOrder{spot=spot,tag=candidate,caption=caption,duty=duty,desk=desk,disabled=disabled});
            // Use the full label width when stepping sideways. Fixed small offsets
            // cannot escape a neighbouring label or the crew clustered at the door.
            for(int row=0;row<63;row++){
                int column=row%9, band=row/9;
                float dx=-width*.5f+(column==0?0:(column%2==1?-1:1)*((column+1)/2))*(width+8);
                float dy=band==0?16:(band%2==1?-1:1)*((band+1)/2)*39;
                tag=new Rect(Mathf.Clamp(at.x+dx,8,w-width-8),at.y+dy,width,34);
                if(Fits(tag)){Place(tag);return;}
            }
            // A visible task remains available when its immediate neighbourhood
            // is crowded: find the closest free slot in the rest of the map.
            float distance=float.PositiveInfinity;Rect fallback=default;
            for(float y=82;y+34<=bottom;y+=38)for(float x=8;x+width<=w-8;x+=width+8){
                var candidate=new Rect(x,y,width,34);
                float candidateDistance=(candidate.center-at).sqrMagnitude;
                if(candidateDistance<distance && Fits(candidate)){distance=candidateDistance;fallback=candidate;}
            }
            if(!float.IsPositiveInfinity(distance))Place(fallback);
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
        if(UpdateMapSelection())return true;
        if(Input.GetKeyDown(KeyCode.Home)){
            float centreZ=HallFrontsVisible?-1.05f:1.55f;
            mapOffset=new Vector2(Mathf.Clamp(player.Position.x,-43,19),Mathf.Clamp(player.Position.z-centreZ,-20.5f,4.5f));
        }
        bool left=Input.GetMouseButtonDown(0),right=Input.GetMouseButtonDown(1);
        if((!left && !right) || OverHUD())return false;
        float scale=Mathf.Min(Screen.width/1100f,Screen.height/720f);
        Vector2 mouse=new Vector2(Input.mousePosition.x,Screen.height-Input.mousePosition.y)/scale;
        if(HallFrontsVisible){int front=HallPinAt(Input.mousePosition);if(front>=0){AssignHallFront(front);return true;}}
        for(int i=0;i<mapOrders.Count;i++){
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
        if(right && !StageActive && GuardAtScreen(Input.mousePosition)!=null)return false;
        if(right && !StageActive){
            var pt=cam.WorldToScreenPoint(player.Position+Vector3.up);
            if(pt.z>0 && Vector2.Distance(Input.mousePosition,pt)<Screen.height*.04f){Assign(Duty.Follow);return true;}
        }
        if(left){
            mapSelecting=true;mapSelectionMoved=false;
            mapSelectionStart=mapSelectionEnd=Input.mousePosition;
            mapSelectionExtend=Input.GetKey(KeyCode.LeftShift)||Input.GetKey(KeyCode.RightShift);
            mapSelectionBase=SelectedMembers;
            return true;
        }
        return false;
    }

    void DrawMapOrders()
    {
        if(!command || Event.current.type!=EventType.Repaint)return;
        BuildMapOrders(hudW,hudH);
        foreach(var order in mapOrders){
            var pt=cam.WorldToViewportPoint(order.spot+Vector3.up*.4f);
            Vector2 at=new(pt.x*hudW,(1-pt.y)*hudH);
            bool hover=!order.disabled && order.tag.Contains(Event.current.mousePosition);
            Color tint=order.disabled?brass:mint;
            HallStroke(at,order.tag.center,tint,1);
            Block(new Rect(at.x-3,at.y-3,6,6),tint);
            Block(order.tag,hover?new Color(.18f,.27f,.26f,.98f):ink);
            Block(new Rect(order.tag.x,order.tag.yMax-2,order.tag.width,2),tint);
            Letter(order.tag,order.caption,14,order.disabled?brass:cream,false,TextAnchor.MiddleCenter);
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
                var at=cam.WorldToScreenPoint(crew[i].Position+Vector3.up);
                Rect mark=new(at.x/scale-12,(Screen.height-at.y)/scale-12,24,24);
                Block(mark,ink);Letter(mark,(i+1).ToString(),16,mint,true,TextAnchor.MiddleCenter);
            }
            Rect caption=new(Mathf.Clamp(box.x,8,hudW-145),Mathf.Clamp(box.y-27,82,hudH-CommandPanelHeight-30),137,25);
            Block(caption,ink);Letter(caption,CountMembers(preview)+"人を選択"+(mapSelectionExtend?"・追加":""),13,mint,false,TextAnchor.MiddleCenter);
        }
    }
}
