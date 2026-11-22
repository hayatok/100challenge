using UnityEngine;

public sealed partial class KinseiSession
{
    bool TacticalPoint(Vector3 world,float w,float h,out Vector2 at)
    {
        var p=cam.WorldToViewportPoint(world);
        at=new Vector2(p.x*w,(1-p.y)*h);
        return p.z>0 && at.x>6 && at.x<w-6 && at.y>60 && at.y<h-CommandDockHeight-6;
    }

    Rect TacticalPersonHit(Vector2 at) => new Rect(at.x-22,at.y-34,44,52);
    Rect TacticalPersonBadge(Vector2 at) => new Rect(at.x-12,at.y-29,24,25);

    int TacticalCrewAt(Vector2 mouse,float w,float h,bool badgeOnly=false)
    {
        int found=-1;float best=float.PositiveInfinity;
        for(int i=0;i<crew.Count;i++){
            var person=crew[i];
            if(person.hp<=0 || person.retired || !TacticalPoint(person.Position+Vector3.up*.25f,w,h,out var at))continue;
            if(!TacticalPersonHit(at).Contains(mouse))continue;
            Rect badge=TacticalPersonBadge(at);
            if(badgeOnly && !badge.Contains(mouse))continue;
            float score=(mouse-badge.center).sqrMagnitude+(badge.Contains(mouse)?0:10000);
            if(score<best){best=score;found=i;}
        }
        return found;
    }

    Person TacticalGuardAt(Vector2 mouse,float w,float h,bool badgeOnly=false)
    {
        guardTags[0]=guardTags[1]=default;
        Person found=null;float best=float.PositiveInfinity;
        foreach(var guard in guards){
            if(!IsHallGuard(guard) || guard.hp<=0 || guard.floorYielded || !TacticalPoint(guard.Position+Vector3.up*.25f,w,h,out var at))continue;
            Rect hit=TacticalPersonHit(at);guardTags[guards.IndexOf(guard)]=hit;
            if(!hit.Contains(mouse))continue;
            Rect badge=TacticalPersonBadge(at);
            if(badgeOnly && !badge.Contains(mouse))continue;
            float score=(mouse-badge.center).sqrMagnitude+(badge.Contains(mouse)?0:10000);
            if(score<best){best=score;found=guard;}
        }
        return found;
    }

    void TacticalBorder(Rect r,Color tint,float width=1)
    {
        Block(new Rect(r.x,r.y,r.width,width),tint);Block(new Rect(r.x,r.yMax-width,r.width,width),tint);
        Block(new Rect(r.x,r.y,width,r.height),tint);Block(new Rect(r.xMax-width,r.y,width,r.height),tint);
    }

    void TacticalRing(Vector2 at,float radius,Color tint,float thickness=2)
    {
        for(int j=0;j<16;j++){
            float a=j*Mathf.PI/8,b=(j+1)*Mathf.PI/8;
            HallStroke(at+new Vector2(Mathf.Cos(a)*radius,Mathf.Sin(a)*radius*.64f),
                at+new Vector2(Mathf.Cos(b)*radius,Mathf.Sin(b)*radius*.64f),tint,thickness);
        }
    }

    // Geometric silhouettes, rather than font glyphs: every action retains its
    // identity with Japanese typefaces and at the minimum supported resolution.
    void TacticalOrderIcon(Rect r,Duty duty,bool desk,Color c)
    {
        float x=r.center.x,y=r.center.y;
        if(desk || (finale && duty==Duty.Attend)){
            TacticalBorder(new Rect(x-10,y-8,20,14),c,2);
            HallStroke(new Vector2(x-4,y-13),new Vector2(x,y-8),c,2);
            HallStroke(new Vector2(x+5,y-13),new Vector2(x,y-8),c,2);
            Block(new Rect(x-6,y+9,12,2),c);Block(new Rect(x-1,y+6,2,3),c);
        }else if(duty==Duty.Follow){
            TacticalRing(new Vector2(x,y+6),10,c,1);
            Block(new Rect(x-3,y-10,6,6),c);Block(new Rect(x-5,y-2,10,9),c);
        }else if(duty==Duty.Rest){
            Block(new Rect(x-10,y-2,20,8),c);Block(new Rect(x-10,y-7,4,13),c);
            Block(new Rect(x-9,y+6,3,5),c);Block(new Rect(x+6,y+6,3,5),c);
        }else if(duty==Duty.BoxOffice){
            TacticalBorder(new Rect(x-8,y-11,16,22),c,2);
            for(int i=0;i<3;i++)Block(new Rect(x-4,y-5+i*5,8,2),c);
        }else if(duty==Duty.StageWitness){
            HallStroke(new Vector2(x-11,y+8),new Vector2(x,y-10),c,2);
            HallStroke(new Vector2(x,y-10),new Vector2(x+11,y+8),c,2);
            Block(new Rect(x-11,y+8,22,3),c);Block(new Rect(x-1,y-4,2,10),c);
        }else if(duty==Duty.Backstage){
            TacticalBorder(new Rect(x-9,y-11,17,22),c,2);
            HallStroke(new Vector2(x-3,y-7),new Vector2(x+5,y-10),c,2);
            HallStroke(new Vector2(x+5,y-10),new Vector2(x+5,y+9),c,2);
            Block(new Rect(x+1,y,2,2),c);
        }else{
            Block(new Rect(x-10,y-4,20,4),c);Block(new Rect(x-7,y,3,11),c);Block(new Rect(x+4,y,3,11),c);
            Block(new Rect(x-4,y-12,8,6),c);
        }
    }

    public void DrawTacticalMap()
    {
        if(!command || cam==null || Event.current.type!=EventType.Repaint || OnAir || shopView!=ShopView.None)return;
        // Routes are drawn first, underneath the people and destinations.
        for(int i=0;i<crew.Count;i++){
            Person member=crew[i];
            if(!IsMemberSelected(i) || member.hp<=0 || member.retired || member.path==null || member.corner>=member.path.Length)continue;
            Vector3 prev=member.Position;
            Color tint=member.duty==Duty.Designated?red:mint;
            for(int n=member.corner;n<member.path.Length;n++){
                var next=member.path[n];
                // Clip to the map viewport; no route may cross the command dock.
                var a=cam.WorldToViewportPoint(prev+Vector3.up*.12f);
                var b=cam.WorldToViewportPoint(next+Vector3.up*.12f);
                if(a.z>0 && b.z>0)TacticalRouteSegment(new Vector2(a.x*hudW,(1-a.y)*hudH),new Vector2(b.x*hudW,(1-b.y)*hudH),tint);
                prev=next;
            }
            if(TacticalPoint(member.path[member.path.Length-1]+Vector3.up*.12f,hudW,hudH,out var goal)){
                TacticalRing(goal,13,tint,2);
                Block(new Rect(goal.x-3,goal.y-3,6,6),tint);
            }
        }
        if(HallFrontsVisible){DrawHallMapPin(0);DrawHallMapPin(1);}
        DrawMapOrders();
        guardTags[0]=guardTags[1]=default;
        foreach(var p in everyone){
            if(p.retired || (p.hp<=0 && !(p==brother && phase==Phase.Choice)))continue;
            int member=crew.IndexOf(p);
            bool ally=member>=0 || p==player;
            bool guard=IsHallGuard(p);
            bool important=ally || guards.Contains(p) || p==brother || p==elder || p==boss || p==westSeo || p==westGuests[0] || p==westGuests[1];
            if(!important || !TacticalPoint(p.Position+Vector3.up*.25f,hudW,hudH,out var at))continue;
            bool selected=member>=0 && IsMemberSelected(member);
            bool friendly=ally || p==westGuests[0] || p==westGuests[1];
            bool threat=!friendly && !p.floorYielded && (guards.Contains(p) || p==westSeo || (p==brother && phase==Phase.Floor) || (p==boss && (phase==Phase.Chase || phase==Phase.Showdown)));
            Color tint=friendly?(p==player?gold:mint):threat?red:gold;
            if(selected)TacticalRing(at,22,tint,3);
            else TacticalRing(at,17,new Color(tint.r,tint.g,tint.b,.6f),1);
            Rect badge=TacticalPersonBadge(at);
            Block(new Rect(badge.x-2,badge.y-2,28,29),ink);
            if(threat){
                Vector2 top=new Vector2(at.x,badge.y-2),right=new Vector2(badge.xMax+3,badge.center.y),bottom=new Vector2(at.x,badge.yMax+3),left=new Vector2(badge.x-3,badge.center.y);
                HallStroke(top,right,tint,2);HallStroke(right,bottom,tint,2);HallStroke(bottom,left,tint,2);HallStroke(left,top,tint,2);
                Letter(badge,p.floorYielded?"降":"!",17,tint,true,TextAnchor.MiddleCenter);
            }else{
                TacticalBorder(badge,tint,selected?2:1);
                Letter(badge,member>=0?(member+1).ToString():p==player?"真":p.floorYielded?"降":"人",15,tint,true,TextAnchor.MiddleCenter);
            }
            Rect hit=TacticalPersonHit(at);
            if(guard && !p.floorYielded)guardTags[guards.IndexOf(p)]=hit;
            float hp=Mathf.Clamp01(p.hp/p.maxHp);
            Block(new Rect(at.x-12,at.y+9,24,3),ink);Block(new Rect(at.x-12,at.y+9,24*hp,3),tint);
            bool hover=hit.Contains(Event.current.mousePosition);
            if(hover || (selected && CountMembers(SelectedMembers)==1)){
                string name=guard?GuardName(p):p.name;
                string action=member>=0?DutyName(p):p.floorYielded?"降参":threat?"敵":"";
                string label=name+(action.Length>0?"  "+action:"");
                float width=Mathf.Max(84,label.Length*12+18);
                Rect tag=new Rect(Mathf.Clamp(at.x-width*.5f,6,hudW-width-6),Mathf.Clamp(at.y-59,60,hudH-CommandDockHeight-26),width,22);
                Block(tag,ink);Letter(tag,label,12,cream,false,TextAnchor.MiddleCenter);
            }
        }
    }

    void TacticalRouteSegment(Vector2 a,Vector2 b,Color tint)
    {
        Rect viewport=Rect.MinMaxRect(6,60,hudW-6,hudH-CommandDockHeight-6);
        if(!ClipChartLine(viewport,ref a,ref b))return;
        HallStroke(a,b,new Color(0,.03f,.03f,.9f),5);
        HallStroke(a,b,tint,2);
    }

    static bool ClipChartLine(Rect bounds,ref Vector2 a,ref Vector2 b)
    {
        // Liang-Barsky clipping in layout coordinates keeps long routes visible
        // while endpoints leave the viewport during a pan.
        Vector2 delta=b-a;float low=0,high=1;
        bool Clip(float p,float q){
            if(Mathf.Abs(p)<.0001f)return q>=0;
            float t=q/p;
            if(p<0){if(t>high)return false;low=Mathf.Max(low,t);}
            else{if(t<low)return false;high=Mathf.Min(high,t);}
            return true;
        }
        if(!Clip(-delta.x,a.x-bounds.xMin) || !Clip(delta.x,bounds.xMax-a.x) ||
           !Clip(-delta.y,a.y-bounds.yMin) || !Clip(delta.y,bounds.yMax-a.y))return false;
        b=a+delta*high;
        a+=delta*low;
        return true;
    }
}
