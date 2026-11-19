using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public static class MarketPassage
    {
        public static readonly Vector3 Gate=new Vector3(-7,0,-4.6f);
        public static readonly Vector3 Shutter=new Vector3(-10.025f,0,-4.6f);
        public const float GateHeight=2.35f;
    }

    public partial class GameSim
    {
        static readonly Vector3 MarketQueue=new Vector3(-8.75f,0,-3.45f);
        bool marketMapOpen;
        Vector3[][] marketPaths;
        WorldGeometry marketPathMap;
        EvacuationLine MarketLine=>state!=null && state.index==0?Line(0):null;
        public int ColumnOperatorId(int c)=>Line(c)?.operatorId??-1;
        public int MarketGateCrew(int squad){
            var l=MarketLine;if(l==null || !ColumnsActive || l.finished || l.open || squad<0 || squad>2)return -1;
            var assigned=Find(l.operatorId);
            if(assigned!=null && assigned.active)return assigned.id;
            return ChooseColumnCrew(0,squad,4,false)?.id??-1;
        }
        public float MarketGateLift{
            get{var l=MarketLine;return l==null || !l.open?0:l.marketOpenedAt==0?1:Mathf.Clamp01((Elapsed-l.marketOpenedAt)/.85f);}
        }
        bool MarketDoorClear=>MarketGateLift>=.82f;
        public int MarketAttackerId=>MarketLine is EvacuationLine l && l.marketEnemy!=0?l.marketEnemy-1:-1;
        public int MarketImpactCount=>MarketLine?.impactCount??0;
        public Vector3 MarketImpactPoint=>MarketLine?.impactPoint??Vector3.zero;
        public float MarketImpactAge=>MarketImpactCount==0?float.PositiveInfinity:Elapsed-MarketLine.impactTime;
        public bool MarketCharging=>Find(MarketAttackerId) is Unit e && e.active && Brain(e).chargeTime>0;
        bool MarketAttackPending=>Find(MarketAttackerId) is Unit e && e.active && (Brain(e).preparingCharge || Brain(e).chargeTime>0);
        bool MarketPassingImpact(EvacuationLine l)=>MarketColumn && l.route==1 && l.leg==1 && MarketImpactAge<4.5f;
        bool MarketAtDoor(EvacuationLine l)=>l.route==1 && l.leg==1 && !l.marketBypass && l.marketStep==1;
        public bool MarketWaiting(int id){
            var l=MarketLine;
            if(l==null || id<0 || l.finished || l.route<0)return false;
            bool rider=System.Array.IndexOf(l.people,id)>=0;
            if(!rider && id!=l.lead)return false;
            if(l.held || (l.route==1 && l.leg==1 && l.marketStep==0 && MarketAttackPending))return true;
            if(!rider || !MarketAtDoor(l) || id==l.marketFirst)return false;
            var first=Find(l.marketFirst);
            return first!=null && first.active && first.pos.z> -4.95f;
        }
        public bool MarketCrossing(int id){
            var l=MarketLine;
            return l!=null && !l.finished && MarketAtDoor(l) && System.Array.IndexOf(l.people,id)>=0 &&
                Find(id) is Unit p && p.moving && Mathf.Abs(p.pos.z+4.6f)<1.25f;
        }
        Vector3 MarketStop(int route,int leg,int step,bool bypass){
            if(leg==2)return Ground(Route.exit);
            if(leg==0)return route==1?MarketQueue:Mark(0,-2);
            if(route!=1 || step>=2)return Mark(3,-12);
            return Mark(bypass?-13:-7,step==0?-3.65f:-5.85f);
        }
        Vector3 MarketGoal(EvacuationLine l)=>MarketStop(l.route,l.leg,l.marketStep,
            l.marketStep==0?!MarketDoorClear:l.marketBypass);
        bool AdvanceMarketStop(EvacuationLine l){
            if(l.leg!=1 || l.route!=1 || l.marketStep>=2)return false;
            if(l.marketStep==0){
                l.marketBypass=!MarketDoorClear;
                float nearest=float.PositiveInfinity;
                var door=Mark(-7,-4.6f);
                foreach(int id in l.people){var p=Find(id);float d=FlatSq(p.pos,door);if(p.active && d<nearest){l.marketFirst=id;nearest=d;}}
            }
            l.marketStep++;
            return true;
        }
        public Vector3[] MarketRoutePoints(int route){
            if(state==null || state.index!=0 || route<0 || route>1)return System.Array.Empty<Vector3>();
            if(marketPathMap!=geometry){marketPaths=new Vector3[2][];marketPathMap=geometry;}
            if(marketPaths[route]!=null)return marketPaths[route];
            var path=new List<Vector3>{ColumnStart(0)};
            for(int leg=0;leg<3;leg++){
                int steps=route==1 && leg==1?3:1;
                for(int step=0;step<steps;step++){
                    var end=MarketStop(route,leg,step,!MarketDoorClear);
                    for(int i=0;i<32;i++){
                        var current=path[path.Count-1];if(FlatSq(current,end)<.001f)break;
                        var next=geometry.Waypoint(current,end);if(FlatSq(current,next)<.00001f)break;
                        path.Add(next);
                    }
                }
            }
            return marketPaths[route]=path.ToArray();
        }
        void TickMarket(){
            var l=MarketLine;if(l==null)return;
            if(!l.marketInitialized){
                // A v0.4 escort already south of the shutter should continue toward the bus.
                l.marketInitialized=true;
                if(l.leg==1 && l.route==1 && System.Array.TrueForAll(l.people,id=>!Find(id).active || Find(id).pos.z<MarketPassage.Gate.z)){
                    l.marketStep=2;
                }
            }
            if(marketMapOpen!=MarketDoorClear){
                marketMapOpen=MarketDoorClear;
                geometry=new WorldGeometry(state.index,Route,marketOpen:marketMapOpen);
                foreach(var a in state.actors)a.hasPath=false;
            }
            if(!ColumnsActive || l.finished || l.held || l.leg!=1 || l.marketStep!=0 || l.marketEnemy!=0)return;
            var target=Find(l.lead);if(target==null || !target.active)return;
            if(l.route==1 && Controlled!=null && FlatSq(Controlled.pos,MarketQueue)<4)target=Controlled;
            // The attacker emerges from the side alley in view of the waiting column.
            var e=Spawn(UnitKind.Infected,Mark(-4.8f,1.35f),"感染者",-1);
            l.marketEnemy=e.id+1;e.variant=1;e.hp=e.maxHp=53;
            var aEnemy=Brain(e);aEnemy.target=target.id;aEnemy.lostTime=1.8f;
            var heading=target.pos-e.pos;
            if(heading.sqrMagnitude<=49 && heading.sqrMagnitude>=4 && geometry.LineClear(e.pos+Vector3.up,target.pos+Vector3.up)){
                aEnemy.chargeHeading=heading.normalized;aEnemy.preparingCharge=true;e.windup=.92f;
                e.yaw=Mathf.Atan2(heading.x,heading.z)*Mathf.Rad2Deg;
            }
        }
        bool RegisterMarketImpact(Unit e,ActorMemory a,Vector3 start,Vector3 intended){
            if(e.id!=MarketAttackerId)return false;
            const float face=-4.6f, clearance=.41f;
            float edge=start.z>face?face+clearance:face-clearance;
            if((start.z-edge)*(intended.z-edge)>0 || Mathf.Abs(intended.z-start.z)<.0001f)return false;
            float fraction=(edge-start.z)/(intended.z-start.z);
            float x=Mathf.Lerp(start.x,intended.x,fraction);
            if(x< -12 || x> -8.05f)return false;
            var contact=Vector3.Lerp(start,intended,fraction);
            if(!geometry.LineClear(start+Vector3.up,contact+Vector3.up))return false;
            var target=Find(a.target);
            if(target!=null && target.active && FlatSq(contact,target.pos)<1.21f)return false;
            var beforeFace=Vector3.MoveTowards(contact,start,.01f);
            var reached=geometry.Move(start,beforeFace);
            if(FlatSq(reached,beforeFace)>.001f)return false;
            e.pos=reached;
            var l=MarketLine;l.impactCount++;l.impactTime=Elapsed;l.impactPoint=new Vector3(x,1.1f,face);
            a.preparingCharge=false;a.chargeTime=0;a.stun=4.5f;a.fireDelay=4.5f;a.hasPath=false;
            e.stagger=a.stun;e.moving=false;
            return true;
        }
    }
}
