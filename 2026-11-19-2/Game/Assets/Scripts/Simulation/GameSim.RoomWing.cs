using System;
using UnityEngine;

namespace Evac
{
    [Serializable]
    internal sealed class WingMemory
    {
        public int stationMask, alternateMask, doors, resident=-1, leader=-1;
        public bool complete, lost, sentryAlert;
        public Vector3 freight;
        public int freightRunner=-1, passengerA=-1, passengerB=-1, crowdArrived;
        public Vector3 freightGoal,freightWay;
        public bool freightPath, oxygenDelivered, shuttleArrived;
        public int[] jobs=new int[3], workers=new int[3];
    }

    public partial class GameSim
    {
        static readonly string[] WingTitles={"夜間診療棟","港の荷さばき棟","駅務区の改札棟","河岸の車両工場"};
        static readonly string[] WingNames={"看護師の黒田","薬剤師の野口","検品係の杉本","荷役主任の渋谷","駅員の川端","案内係の石田","配車係の成瀬","整備士の倉田"};
        // Reception and plant can be staffed independently. The third and fourth rooms
        // offer a survivor and a fallback supply route; northern exits are exclusive.
        static readonly string[,,] WingTasks={
            {{"名簿から病室を照合","救急箱で先に処置"},{"病棟の電源を戻す","薬品庫へ給電"},{"看護記録を持って同行","予備の担架で同行"},{"非常口の鍵を回収","薬品庫から救急箱を回収"},{"救護室へ引き継ぐ",""},{"住民の診療所へ引き継ぐ",""}},
            {{"送り状で荷主を確認","予備の運搬具を出す"},{"搬送ベルトを西へ送る","搬送ベルトを東へ送る"},{"検品札を合わせて同行","台車で同行"},{"非常通路の鎖を外す","予備部品を積み替える"},{"作業員用の北口に誘導",""},{"荷台まで誘導して部品を渡す",""}},
            {{"避難名簿と乗車券を照合","構内電話の電池を交換"},{"西改札への放送","東通路への放送"},{"駅員と一緒に移動","救護用の車椅子で移動"},{"連絡通路を手で開ける","駅務室の無線機を回収"},{"駅務室の避難列へ誘導",""},{"北ホームで避難列を編成",""}},
            {{"故障車の車番を照合","救援車に予備燃料を積む"},{"西側リフトを起動","東側の配車線を復旧"},{"作業員を工場から誘導","作業員を救援車で介助"},{"整備通路の差し錠を抜く","交換用の車軸を回収"},{"運転班に引き継ぐ",""},{"配車室で救援車を手配",""}}
        };
        static readonly string[,] RoomNames={
            {"夜間受付","配電室","観察病室","薬品庫","救護室","地域診療所"},
            {"検量窓口","搬送盤","検品室","荷さばき場","作業員出口","積載口"},
            {"改札窓口","放送室","駅務室","連絡通路","北改札","北ホーム"},
            {"整備受付","動力室","点検ピット","部品庫","運転班詰所","配車室"}
        };
        public string WingRoomName(int station)=>station>=0 && station<6?RoomNames[WingRegion,station]:"";
        public bool WingRoomOpen(int side)=>side>=0 && side<2 && (WingDoorMask&(1<<side))!=0;
        public bool WingStationDone(int station)=>station>=0 && station<6 && WingDone(station);
        public int WingSquadStation(int squad)=>WingAssignment(squad);
        public int WingRecommendedStation=>!WingDone(0)?0:!WingDone(1)?1:!WingDone(2)?2:4;
        static bool ValidWing(MissionMemory m)
        {
            if(m.wingRevision==0)return true;
            var w=m.wing;
            if(m.wingRevision!=1 || m.duty || w==null || w.jobs?.Length!=3 || w.workers?.Length!=3 ||
                w.stationMask<0 || w.stationMask>63 || w.alternateMask<0 || (w.alternateMask&~w.stationMask)!=0 ||
                w.doors<0 || w.doors>3)return false;
            foreach(int job in w.jobs)if(job!=0 && (job<2 || job>13))return false;
            return !float.IsNaN(w.freight.x) && !float.IsNaN(w.freight.z) && !float.IsInfinity(w.freight.x) && !float.IsInfinity(w.freight.z);
        }
        void BringWingReturnee(int mission)
        {
            if(IsDuty || mission<1 || campaign.wingReturns?.Length!=8 || campaign.wingReturns[mission-1]==0)return;
            var aide=Spawn(UnitKind.Civilian,Route.depot+Vector3.forward*2,WingNames[mission-1],-1);
            Brain(aide).auxiliary=true;
            state.wingAide=aide.id+1;
            state.wingService=campaign.wingReturns[mission-1];
            state.wingUses=2;
        }

        bool IsWingAide(Unit u)=>u!=null && state.wingAide==u.id+1;
        void ServeWingAide(Unit aide,float dt)
        {
            if(state.wingUses<=0)return;
            foreach(var s in soldiers){
                if(!s.active || FlatSq(s.pos,aide.pos)>9)continue;
                if(state.wingService==1 && s.hp<=70){
                    s.hp=Mathf.Min(s.maxHp,s.hp+30);s.wounded=s.hp<80;state.wingUses--;
                    SoundNotice(aide.name+"が"+s.name+"の傷を手当て");return;
                }
                if(state.wingService==2 && s.reserve<=36){
                    s.reserve+=24;state.wingUses--;
                    SoundNotice(aide.name+"が"+s.name+"に予備弾を届けました");return;
                }
            }
        }
        int WingRegion=>state.index/2;
        WingMemory Wing=>state.wingRevision==1?state.wing:null;
        public bool WingActive=>IsReady && !IsDuty && Wing!=null && ChapterPhase==2 && Sector>=1 && Result==SimResult.Active;
        public bool WingComplete=>Wing!=null && Wing.complete;
        public string WingTitle=>WingTitles[WingRegion];
        public string WingResidentName=>WingNames[state.index];
        public bool WingHasFreight=>WingActive && WingDone(1) && !WingComplete && (WingRegion==1 ||
            (WingRegion==0 && (Wing.alternateMask&2)==0 && !Wing.oxygenDelivered) || (WingRegion==3 && (Wing.alternateMask&2)!=0));
        public string WingFreightLabel=>WingRegion==0?"酸素ボンベ":WingRegion==1?"荷役台車":"構内救援車";
        public Vector3 WingFreightPosition=>Wing?.freight??Vector3.zero;
        public int WingEscortId=>Wing?.leader??-1;
        public int WingResidentId=>Wing?.resident??-1;
        public bool CanTakeWingFreight=>WingHasFreight && WingRegion!=3 && (WingRegion!=1 || WingDone(3) && (Wing.alternateMask&2)!=0) &&
            Controlled!=null && Wing.freightRunner!=Controlled.id && FlatSq(Controlled.pos,Wing.freight)<=9;
        public bool WingTakeCart()
        {
            if(!CanTakeWingFreight)return false;
            Wing.freightRunner=Controlled.id;SoundNotice(WingFreightLabel+"を受け取りました");return true;
        }
        public bool CanRejoinWingResident
        {
            get{
                var c=Find(WingResidentId);
                return WingActive && !WingComplete && WingDone(2) && c!=null && c.active && Controlled!=null &&
                    Wing.leader!=Controlled.id && FlatSq(c.pos,Controlled.pos)<=9;
            }
        }
        public bool WingRejoin()
        {
            if(!CanRejoinWingResident)return false;
            Wing.leader=Controlled.id;SoundNotice(WingResidentName+"が"+Controlled.name+"に同行");return true;
        }
        public int WingDoorMask=>Wing?.doors??0;
        public int WingStationMask=>Wing?.stationMask??0;
        public int WingAssignment(int squad)=>Wing!=null && squad>=0 && squad<3?Wing.jobs[squad]/2-1:-1;
        public Vector3 WingPosition(int station)=>RoomWingLayout.Station(Mathf.Clamp(station,0,5));
        public string WingAction(int station,int option)=>station>=0 && station<6 && option>=0 && option<2?WingTasks[WingRegion,station,option]:"";
        bool WingDone(int i)=>(WingStationMask&(1<<i))!=0;
        public string WingStatus=>WingComplete?(Wing.lost?"住民の遺留品を引き継ぎました":WingResidentName+"を引き継ぎました"):
            !WingDone(0)?"受付で身元を確認。設備室にも班を送れます":!WingDone(2)?WingResidentName+"を迎えてください":
            Wing.lost?"住民を失いました。北口で遺留品を引き渡してください":"北の引継所へ同行。東側では資材も引き渡せます";
        public string WingCondition(int station)
        {
            if(WingDone(station))return "対応済み";
            if(station==2)return "受付と設備を確認。備蓄1で介助し移動を速める";
            if(station==1)return new[]{"西は病室へ酸素を運び全快、東は救急箱＋2","西は搬出用コンベヤー、東は荷受け側から台車で搬出","西放送は感染者を西口へ誘引、東放送は街の襲来を遅延","西は車体＋24、東は備蓄＋2と救援車"}[WingRegion];
            if(station==3)return "設備設定後。両扉を開けるか、備蓄＋1と北の引渡し";
            if(station==4)return "住民と到着。救急箱＋2。次の作戦は救護員と救急箱＋2";
            if(station==5)return "資材と住民を引渡し。備蓄＋2、車体＋18。次の作戦は補給員と備蓄＋2";
            return station==0?"備蓄1で患者を処置し、設備より先に同行可":"どちらかの扉に給電";
        }

        public bool WingAvailable(int station,int option)
        {
            if(!WingActive || WingComplete || WingAction(station,option)=="" || WingDone(station))return false;
            if(option==1 && (station==0 || station==2) && Stock<1)return false;
            if(station==2)return WingDone(0) && (WingDone(1) || (Wing.alternateMask&1)!=0);
            if(station==3)return WingDone(1);
            if(station>=4)return WingDone(2) && (station==4 || (Wing.alternateMask&8)!=0);
            return true;
        }

        public bool DispatchWing(int squad,int station,int option)
        {
            if(!WingAvailable(station,option) || squad<0 || squad>=3)return false;
            if(!soldiers.Exists(u=>u.active && u.squad==squad))return false;
            var group=state.squads[squad];
            var previous=(SquadOrder)group.order;var hold=group.assigned?group.destination:Route.exit;
            if(!Order(squad,previous,hold))return false;
            Unit worker=Find(Wing.workers[squad]-1);
            if(worker==null || !worker.active || worker==Controlled){
                worker=null;float best=float.PositiveInfinity;
                foreach(var candidate in soldiers){
                    if(!candidate.active || candidate.squad!=squad || candidate==Controlled)continue;
                    var actor=Brain(candidate);
                    float distance=FlatSq(candidate.pos,WingPosition(station))+(actor.cargo || actor.escort>=0?100000:0);
                    if(distance<best){best=distance;worker=candidate;}
                }
            }
            Wing.workers[squad]=worker==null?0:worker.id+1;
            Wing.jobs[squad]=(station+1)*2+option;
            return true;
        }

        bool WithinWingDesk(Unit actor,int station)
        {
            if(actor==null || station<0 || station>=6)return false;
            var desk=WingPosition(station);
            return FlatSq(actor.pos,desk)<=2.3f*2.3f && geometry.LineClear(actor.pos+Vector3.up,desk+Vector3.up);
        }

        public bool AtWingStation(int station)=>WithinWingDesk(Controlled,station);

        public string WingDirectRequirement(int station,int option)=>WingRequirement(Controlled,station,option);

        string WingRequirement(Unit actor,int station,int option)
        {
            if(!WingAvailable(station,option))return "この対応に必要な作業が残っています";
            if(!WithinWingDesk(actor,station))return "設備の前まで近づいてください";
            if(station==2 && WingHasFreight && WingRegion==0 && option==0 && !Wing.oxygenDelivered)
                return "酸素ボンベを病室まで運んでください";
            if(station==5 && WingRegion==3 && WingHasFreight && !Wing.shuttleArrived)
                return "配車室に救援車が着くと引き渡せます";
            if(station==5 && WingRegion==1 && FlatSq(Wing.freight,WingPosition(5))>12)
                return "積載口まで荷役台車を運んでください";
            if(station>=4 && !Wing.lost)
            {
                var resident=Find(Wing.resident);
                if(resident==null || FlatSq(resident.pos,actor.pos)>16)
                    return WingResidentName+"と一緒に引継所へ来てください";
            }
            return "";
        }

        public bool UseWing(int station,int option)=>Controlled!=null && OperateWing(Controlled,station,option);
        bool OperateWing(Unit u,int station,int option)
        {
            if(WingRequirement(u,station,option).Length!=0)return false;
            var resident=Find(Wing.resident);
            if(station==0 && option==1 || station==2 && option==1)state.stock--;
            Wing.stationMask|=1<<station;
            if(option==1)Wing.alternateMask|=1<<station;
            switch(station){
                case 0:
                    if(option==1 && resident!=null)resident.hp=resident.maxHp;
                    break;
                case 1:
                    Wing.doors|=1<<option;
                    if(WingRegion==0 && option==0){Wing.freight=WingPosition(1);Wing.freightRunner=u.id;}
                    if(WingRegion==0 && option==1)state.medPacks+=2;
                    if(WingRegion==1)Wing.freight=WingPosition(option==0?3:1);
                    if(WingRegion==2 && option==0)Wing.sentryAlert=true;
                    if(WingRegion==2 && option==1)state.waveIn+=Route.waveInterval*.45f;
                    if(WingRegion==3 && option==0)state.vehicle=Mathf.Min(100,state.vehicle+24);
                    if(WingRegion==3 && option==1){state.stock+=2;Wing.freight=WingPosition(0);}
                    break;
                case 2:
                    Wing.leader=u.id;
                    break;
                case 3:
                    if(option==0)Wing.doors=3;
                    else{
                        state.stock++;
                        if(WingRegion==1){
                            Wing.freightRunner=u.id;
                            if((Wing.alternateMask&2)==0)Wing.freight=WingPosition(3);
                        }
                    }
                    break;
                default:
                    Wing.complete=true;
                    if(resident!=null){resident.active=false;}
                    if(!Wing.lost){
                        if(station==4)state.medPacks+=2;
                        else {state.stock+=2;state.vehicle=Mathf.Min(100,state.vehicle+18);}
                    }
                    break;
            }
            geometry.SetWingDoors(Wing.doors);WalkingMap.SetWingDoors(Wing.doors);
            foreach(var a in state.actors)a.hasPath=false;
            SoundNotice(WingAction(station,option)+"　"+WingStatus);
            Save();return true;
        }

        void PrepareWing(float wingStep)
        {
            if(!WingActive || WingComplete)return;
            geometry.SetWingDoors(Wing.doors);WalkingMap.SetWingDoors(Wing.doors);
            if(Wing.sentryAlert){
                Wing.sentryAlert=false;
                var contact=Spawn(UnitKind.Infected,WingPosition(0)+Vector3.forward*3,"構内の感染者",-1);
                contact.hp=contact.maxHp=53;
            }
            if(WingRegion==2 && WingDone(1) && Wing.passengerA<0){
                Wing.passengerA=SpawnWingPassenger(3,"改札の乗客");
                Wing.passengerB=SpawnWingPassenger(0,"切符売場の乗客");
            }
            if(WingHasFreight && WingRegion==0){
                PullWingFreight(wingStep);
                if(FlatSq(Wing.freight,WingPosition(2))<=7){
                    Wing.oxygenDelivered=true;
                    var patient=Find(Wing.resident);if(patient!=null)patient.hp=patient.maxHp;
                    SoundNotice("病室の酸素を復旧");
                }
            }
            if(WingHasFreight && WingRegion==3 && WingDone(3)){
                MoveWingFreight(WingPosition(5),3.2f,wingStep);
                Wing.shuttleArrived=FlatSq(Wing.freight,WingPosition(5))<4;
            }
            if(WingHasFreight && WingRegion==1 && WingDone(3) && (Wing.alternateMask&8)!=0){
                if((Wing.alternateMask&2)==0)MoveWingFreight(WingPosition(5),2.4f,wingStep);
                else {
                    PullWingFreight(wingStep);
                }
            }
            if(Wing.resident>=0)return;
            var u=Spawn(UnitKind.Civilian,WingPosition(2)+Vector3.forward*.65f,WingResidentName,-1);
            Wing.resident=u.id;u.hp=54;Brain(u).auxiliary=true;
        }

        void PullWingFreight(float dt)
        {
            var hauler=Find(Wing.freightRunner);
            if(hauler!=null && hauler.active && FlatSq(hauler.pos,Wing.freight)<12)
                MoveWingFreight(hauler.pos,5.6f,dt);
        }
        void MoveWingFreight(Vector3 goal,float speed,float dt)
        {
            var w=Wing;
            if(!w.freightPath || FlatSq(goal,w.freightGoal)>.45f || FlatSq(w.freight,w.freightWay)<.008f){
                w.freightPath=true;w.freightGoal=goal;w.freightWay=WalkingMap.Waypoint(w.freight,goal);
            }
            w.freight=WalkingMap.Move(w.freight,Vector3.MoveTowards(w.freight,w.freightWay,speed*dt));
        }
        int SpawnWingPassenger(int station,string name)
        {
            var passenger=Spawn(UnitKind.Civilian,WingPosition(station),name,-1);
            Brain(passenger).auxiliary=true;
            return passenger.id;
        }
        bool WingPassenger(Unit u)=>Wing!=null && u!=null && (Wing.passengerA==u.id || Wing.passengerB==u.id);
        void RouteWingPassenger(Unit u,float dt)
        {
            int destination=(Wing.alternateMask&2)==0?4:5;
            if(!Walk(u,WingPosition(destination),2.9f,dt))return;
            u.active=false;Wing.crowdArrived++;
            state.volunteers++;state.depotRounds+=12;
            SoundNotice(u.name+"が北口の避難列に到着");
        }
        bool WingResident(Unit u)=>Wing!=null && u!=null && Wing.resident==u.id;
        void FollowWing(Unit u,float dt)
        {
            if(!WingDone(2) || WingComplete)return;
            var leader=Find(Wing.leader);
            if(leader==null || !leader.active || FlatSq(leader.pos,u.pos)>16){
                Unit local=null;float best=16;
                foreach(var s in soldiers){
                    float d=FlatSq(s.pos,u.pos);
                    if(s.active && d<best){best=d;local=s;}
                }
                if(local!=null){leader=local;Wing.leader=local.id;}
            }
            if(leader!=null && leader.active && FlatSq(leader.pos,u.pos)>1.1f)
                Walk(u,leader.pos,(Wing.alternateMask&4)!=0?4.25f:3.4f,dt);
        }

        bool TravelWing(Unit u,float dt)
        {
            if(!WingActive || WingComplete || Wing.jobs[u.squad]<2)return false;
            var worker=Find(Wing.workers[u.squad]-1);
            if(worker!=null && worker.active && worker!=Controlled && worker!=u)return false;
            Wing.workers[u.squad]=u.id+1;
            int job=Wing.jobs[u.squad],station=job/2-1,option=job%2;
            if(!WingAvailable(station,option)){Wing.jobs[u.squad]=0;return false;}
            var brain=Brain(u);
            if(brain.fireDelay==0 && u.reload<=0 && u.ammo>0){
                var contact=PriorityContact(u,15)??NearestThreat(u.pos,15);
                if(contact!=null)HitShot(u,contact,(contact.pos-u.pos).normalized,true);
            }
            if(u.ammo==0)StartReload(u);
            var resident=Find(Wing.resident);
            if(station>=4 && !Wing.lost && resident!=null){
                var leader=Find(Wing.leader);
                if(leader!=u){
                    if(FlatSq(u.pos,resident.pos)>4){Walk(u,resident.pos,4,dt);return true;}
                    Wing.leader=u.id;
                }
            }
            if((station==2 && WingRegion==0 && WingHasFreight && option==0) || (station==5 && WingRegion==1 && (Wing.alternateMask&2)!=0 && FlatSq(Wing.freight,WingPosition(5))>12)){
                var hauler=Find(Wing.freightRunner);
                if(hauler!=u || FlatSq(u.pos,Wing.freight)>10){
                    if(FlatSq(u.pos,Wing.freight)>4){Walk(u,Wing.freight,4,dt);return true;}
                    Wing.freightRunner=u.id;
                }
            }
            if(!OperateWing(u,station,option))Walk(u,WingPosition(station),4,dt);
            return true;
        }
    }
}
