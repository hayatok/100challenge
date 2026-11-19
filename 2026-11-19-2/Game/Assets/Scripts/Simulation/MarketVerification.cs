#if UNITY_EDITOR
using System.Text;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        void WalkMarketPlayer(Vector3 destination){
            var p=Controlled;var delta=RouteWaypoint(p.pos,destination)-p.pos;
            Move(Vector3.ClampMagnitude(delta/.53f,1),Mathf.Atan2(delta.x,delta.z)*Mathf.Rad2Deg,.1f);
        }
        void VerifyMarketPassage(StringBuilder report){
            for(int style=0;style<3;style++)VerifyMarketRun(style,report);
        }
        void VerifyMarketRun(int style,StringBuilder report){
            StartMission(0,Difficulty.Standard);Chapter.phase=2;Tick(.1f);
            var l=MarketLine;
            var north=MarketPassage.Gate+Vector3.forward;
            var south=MarketPassage.Gate+Vector3.back;
            Verify(geometry.Move(north,south).z>MarketPassage.Gate.z,"Closed gate blocks walking");
            var route=MarketRoutePoints(1);
            Verify(System.Array.Exists(route,v=>v.x< -12.5f) && FlatSq(route[route.Length-1],Route.exit)<.01f,"Bypass trace reaches bus");
            var street=MarketRoutePoints(0);
            Verify(street.Length>=3 && FlatSq(street[street.Length-1],Route.exit)<.01f,"Main street trace reaches bus");
            bool manual=style==1,mixed=style==2;
            if(manual)Verify(Possess(soldiers[0].id),"Enter first person");
            else Verify(CommandColumn(0,1,0),"Dispatch distinct escort");
            if(mixed){
                int opener=MarketGateCrew(0);
                Verify(opener>=0 && opener!=l.lead && CommandColumn(0,4,0) && ColumnOperatorId(0)==opener &&
                    Possess(opener),"Enter the dispatched independent opener");
            }
            bool dodged=false,resumed=false;int crossed=0;float firstCross=-1,lastCross=-1;
            var gates=new float[2];
            for(int i=0;i<1000 && !l.finished && Result==SimResult.Active;i++){
                if(manual){
                    if(l.held && CanCommandColumn(0,0,Controlled.squad))CommandColumn(0,0,Controlled.squad);
                    WalkMarketPlayer(l.held?ColumnPosition(0):MarketGoal(l));
                    if(Find(MarketAttackerId) is Unit hostile && hostile.active)Shoot((hostile.pos-Controlled.pos).normalized);
                }
                if(mixed){
                    if(!l.open){
                        WalkMarketPlayer(ColumnControlPoint(0));
                        if(CanCommandColumn(0,4,Controlled.squad))Verify(CommandColumn(0,4,Controlled.squad),"Open gate as dispatched operator");
                    }else if(!dodged){
                        if(Find(MarketAttackerId) is Unit hostile && Brain(hostile).preparingCharge){
                            dodged=Dodge(Vector3.left);
                        }else WalkMarketPlayer(MarketQueue);
                    }
                }
                var before=new[]{Find(l.people[0]).pos,Find(l.people[1]).pos};
                Tick(.1f);
                for(int j=0;j<2;j++){
                    var after=Find(l.people[j]).pos;
                    Verify(FlatSq(before[j],after)<.18f,"Shopkeeper moves continuously");
                    if(before[j].z> -4.6f && after.z<= -4.6f && gates[j]==0){
                        gates[j]=after.x;crossed++;if(firstCross<0)firstCross=Elapsed;lastCross=Elapsed;
                    }
                }
                if(mixed && !resumed && MarketImpactCount>0){
                    var at=MarketImpactPoint;
                    int lead=l.lead;int enemy=MarketAttackerId;
                    Verify(Save() && Load() && MarketImpactCount==1 && MarketImpactPoint==at &&
                        MarketAttackerId==enemy && ColumnLeaderId(0)==lead,"Resume specific impact, leader and attacker");
                    l=MarketLine;resumed=true;
                }
            }
            Verify(l.arrived==2 && crossed==2,"Both boarded in market play style "+style+" at "+Elapsed+" status "+ColumnStatus(0)+" lead "+Find(l.lead)?.pos+" members "+ColumnPosition(0));
            if(style==0)Verify(gates[0]< -12 && gates[1]< -12 && MarketImpactCount==0,"Closed bypass used by both, no false impact on a soldier");
            if(manual)Verify(gates[0]> -5 && gates[1]> -5,"Both used main street");
            if(mixed){
                Verify(dodged && resumed && MarketImpactCount==1,"Dodge led to physical shutter impact; dodge="+dodged+" hits="+MarketImpactCount);
                Verify(gates[0]> -8 && gates[0]< -6 && gates[1]> -8 && gates[1]< -6 &&
                    lastCross-l.impactTime<4.5f && firstCross>=l.impactTime && lastCross-firstCross>=.25f,"Last rider crossed during authentic recovery");
                Verify(FlatSq(geometry.Move(north,south),south)<.001f &&
                    !System.Array.Exists(MarketRoutePoints(1),v=>v.x< -12.5f),"Open gate geometry and route agree");
            }
            int hurt=0;foreach(int id in l.people)if(Find(id).hp<100)hurt++;
            report.AppendLine("Market Standard "+(manual?"FPS main street":mixed?"mixed open door":"RTS closed bypass")+
                " boarded="+l.arrived+" injured="+hurt+" crossing x="+gates[0]+","+gates[1]+" impact="+MarketImpactCount+" seconds="+Elapsed);
        }
    }
}
#endif
