using System;
using UnityEngine;

namespace Evac
{
    [Serializable] internal sealed class EvacuationLine
    {
        public int[] people;
        public int route=-1, leg, lead=-1, operatorId=-1, medic=-1, carrier=-1, pickup=-1, carried=-1, arrived, sheltered, lost;
        public bool held=true, open, joined, finished;
        public Vector3 refuge;
        public float stretcherYaw;
        public int marketStep, marketFirst, marketEnemy, impactCount;
        public bool marketBypass, marketInitialized, marketMeeting;
        public float marketOpenedAt, impactTime;
        public Vector3 impactPoint;
    }

    public partial class GameSim
    {
        static readonly string[][] Manifest={
            new[]{"八百屋の中野","花屋の谷口"},
            new[]{"車掌の井口","通学生の島田","売店の坂本","乗客の松井"},
            new[]{"看護師の早川","足を痛めた牧野","乗客の大橋","杖を使う青山"}
        };
        bool MarketColumn=>state.index==0;
        public bool ColumnsActive=>IsReady && state.columnVersion==1 && !IsDuty && ChapterPhase==2 &&
            Result==SimResult.Active && state.lines!=null && state.lines.Length>0;
        public int ColumnCount=>state.columnVersion==1 && state.lines!=null?state.lines.Length:0;
        public bool ColumnsComplete{
            get{if(ColumnCount==0)return false;foreach(var l in state.lines)if(!l.finished)return false;return true;}
        }
        EvacuationLine Line(int c)=>c>=0 && c<ColumnCount?state.lines[c]:null;
        public int ColumnMemberCount(int c)=>Line(c)?.people.Length??0;
        public int ColumnMemberId(int c,int i)=>i>=0 && i<ColumnMemberCount(c)?Line(c).people[i]:-1;
        public int ColumnMemberOutcome(int c,int i){var u=Find(ColumnMemberId(c,i));return u==null?0:Brain(u).columnOutcome;}
        public int ColumnLeaderId(int c)=>Line(c)?.lead??-1;
        public int ColumnRoute(int c)=>Line(c)?.route??-1;
        public int ColumnCarrierId(int c)=>Line(c)?.carrier??-1;
        public float ColumnStretcherYaw(int c)=>Line(c)?.stretcherYaw??0;
        public int ColumnCarriedId(int c)=>Line(c)?.carried??-1;
        bool ColumnHandsBusy(Unit u)=>u!=null && ColumnCount==2 && Line(1).carrier==u.id;
        Unit StretcherPatient(int c){
            if(MarketColumn || c!=1 || Line(c)==null)return null;
            var current=Find(Line(c).carried);
            if(current!=null && current.active)return current;
            var first=Find(Line(c).people[1]);
            return first!=null && first.active && first.wounded?first:ColumnPatient(c);
        }
        public bool ColumnControlOpen(int c)=>Line(c)?.open??false;
        public bool ColumnHeld(int c)=>Line(c)?.held??false;
        public bool ColumnFinished(int c)=>Line(c)?.finished??false;
        public string ColumnTitle(int c)=>MarketColumn?"朝市の店主":c==0?"北改札の歩行列":"救護室の介助列";
        public string ColumnCurrentStop(int c){
            var l=Line(c);if(l==null)return "";
            if(l.finished)return l.sheltered>0?"退避所に引継ぎ":"乗車口で引継ぎ";
            if(l.leg==0)return MarketColumn?"青果店前":c==0?"北改札":"救護室";
            if(MarketColumn)
            {
                if(l.leg!=1)return "バス停前";
                if(l.route==0)return "表通り";
                if(l.marketStep==0)return "青果店の軒下";
                if(l.marketStep==1)return l.marketBypass?"露店脇の迂回口":"市場横戸の手前";
                return l.marketBypass?"迂回路の出口":"市場横戸の先";
            }
            if(l.leg==1)return c==0?"北連絡口":"待合室";
            return l.route==0?"昇降機前":"保守通路";
        }
        public string ColumnNextStop(int c){
            var l=Line(c);if(l==null || l.finished)return "";
            if(MarketColumn)
            {
                if(l.leg==0)return l.route<0?"表通り／軒下":l.route==0?"表通り":"青果店の軒下";
                if(l.leg==2)return "バス乗車口";
                if(l.route==0 || l.marketStep>=2)return "バス停前";
                if(l.marketStep==0)return MarketDoorClear || l.marketMeeting?"市場横戸の手前":"露店脇の迂回口";
                return l.marketBypass?"迂回路の出口":"市場横戸の先";
            }
            if(l.leg==0)return c==0?"北連絡口":"待合室";
            if(l.leg==1)return l.route==0?"昇降機前":"保守通路";
            return "列車乗車口";
        }
        public string ColumnStatus(int c){
            var l=Line(c);if(l==null)return "";
            if(l.finished)return "乗車 "+l.arrived+"人　退避 "+l.sheltered+"人　負傷死 "+l.lost+"人";
            if(l.pickup>=0)return "担架の担当が負傷者に向かっています";
            if(c==1 && l.leg==1 && l.route==1 && l.carrier<0 && Find(l.people[1]) is Unit hurt && hurt.active && hurt.wounded)
                return hurt.name+"は階段で担架か手当てが必要";
            if(l.medic>=0)return "救護担当が負傷者のもとへ移動中";
            if(l.marketMeeting && !l.open)return "横戸で待ち合わせ中";
            if(l.operatorId>=0)return "係員が操作盤へ移動中";
            if(l.leg==1 && !l.held && !ColumnPassable(c))return l.route==0?"冠水または停電。排水と昇降機を確認":"防火扉が閉鎖中。係員を操作盤へ";
            if(!MarketColumn && l.leg==1 && l.route==0 && !l.held){
                int waiting=0;
                foreach(int id in l.people){var p=Find(id);if(p.active && !Brain(p).columnLifted && FlatSq(p.pos,ColumnDestination(c))<7)waiting++;}
                if(waiting>0)return "昇降機前で"+waiting+"人が乗降待ち";
            }
            if(l.held)return l.route<0?"進路と付添班を選択":"列は停止中。進路を選んで再開";
            return l.joined?ColumnNextStop(c)+"へ移動中":"付添担当が列に合流中";
        }
        public string ColumnActionLabel(int c,int a){
            switch(a){
                case 0:return MarketColumn?"表通りで誘導":"昇降機経由";
                case 1:return MarketColumn?"軒下から誘導":"保守通路経由";
                case 2:return "列を止める";case 3:return "同行を再開";
                case 4:return MarketColumn?"横戸を開ける":c==0?"誘導放送を入れる":"防火扉を開ける";
                case 5:return "退避所に託す";case 6:return "負傷者を手当て（救急箱1）";case 7:return Controlled!=null && ColumnCarrierId(c)==Controlled.id?"担架を下ろす":"担架を引き受ける";default:return "";
            }
        }
        public string ColumnRouteDetail(int c,int a){
            if(a==0)return MarketColumn?"最短。通りの感染者に注意":"排水と昇降機電源が必要。乗降枠は街の住民と共用";
            if(a==1)return MarketColumn?"店先を通る。横戸を開くと近道":"防火扉を開放。階段では負傷者に付添が必要";
            if(a==4)return MarketColumn?"店主の横戸を解錠":c==0?"西口へ感染者を誘い、付添なしで北列を誘導":"現場で扉を解錠。両列が保守通路を使える";
            if(a==7)return "負傷者を担架で運ぶ。射撃・回避はできない";
            if(a==6)return "現場で救急箱を1個使用。歩ける速さまで回復";
            if(a==5)return "退避所にいる人を残して出発。乗車数に加算しない";
            return "";
        }
        Vector3 Mark(float x,float z)=>Ground(new Vector3(x,0,z));
        Vector3 ColumnStart(int c)=>MarketColumn?Mark(-8,4):c==0?RoomWingLayout.Station(0):RoomWingLayout.Station(3);
        public Vector3 ColumnShelter(int c,int route)=>MarketColumn?Mark(route==0?0:-10,-2):Mark(route==0?5:-8,27);
        public Vector3 ColumnControlPoint(int c)=>MarketColumn?Mark(-6,-3):c==0?RoomWingLayout.Station(1):Mark(-9,57);
        public Vector3 ColumnPosition(int c){
            var l=Line(c);if(l==null)return Vector3.zero;
            foreach(int id in l.people){var u=Find(id);if(u!=null && u.active)return u.pos;}
            return l.refuge;
        }
        public Vector3 ColumnDestination(int c){
            var l=Line(c);if(l==null)return Vector3.zero;
            if(l.finished)return l.refuge;
            if(MarketColumn)return MarketGoal(l);
            if(l.leg==0)return Mark(c==0?-9:9,76);
            if(l.leg==1)return ColumnShelter(c,l.route);
            return Ground(Route.exit);
        }
        Vector3 MemberDestination(int c,Unit p){
            var l=Line(c);var a=Brain(p);
            if(MarketColumn && l.route==1 && p.id==l.people[1]){
                if(l.leg==0 || WaitingAtMarketQueue(l))return MarketQueue+Vector3.left*.95f;
                if(l.leg==1 && l.marketStep==0)return MarketGoal(l)+Vector3.forward*.92f;
            }
            if(!MarketColumn && l.leg==1){if(a.columnLifted)return ColumnShelter(c,0);if(a.columnStairs)return ColumnShelter(c,1);}
            return ColumnDestination(c);
        }
        Unit ColumnPatient(int c){
            var l=Line(c);if(l==null)return null;
            Unit patient=null;
            foreach(int id in l.people){var u=Find(id);if(u.active && (u.wounded || u.hp<70) && (patient==null || u.hp<patient.hp))patient=u;}
            return patient;
        }
        public Vector3 ColumnActionPoint(int c,int a)=>a==4?ColumnControlPoint(c):a==7 && StretcherPatient(c)!=null?StretcherPatient(c).pos:a==6 && ColumnPatient(c)!=null?ColumnPatient(c).pos:ColumnPosition(c);
        public Vector3 ColumnNavigationStep(Vector3 from,Vector3 to)=>WalkingMap.Waypoint(from,to);
        public bool ColumnRouteClear(int c)=>Line(c)!=null && ColumnPassable(c);
        bool ColumnPassable(int c){
            var l=Line(c);
            return MarketColumn || l.leg!=1 || (l.route==0?Water<.73f && (PowerMask&2)!=0:Line(1).open);
        }
        static bool ValidColumns(MissionMemory m){
            if(m.columnVersion==0)return true;
            if(m.columnVersion!=1 || m.duty || (m.index!=0 && m.index!=5))return false;
            if(m.lines==null || m.lines.Length==0)return true;
            if(m.lines.Length!=(m.index==0?1:2))return false;
            var seen=new System.Collections.Generic.HashSet<int>();
            foreach(var l in m.lines){
                if(l==null || l.people?.Length!=(m.index==0?2:4) || l.leg<0 || l.leg>3 || l.route< -1 || l.route>1)return false;
                foreach(int id in l.people)if(!seen.Add(id) || !m.units.Exists(u=>u.id==id && u.kind==UnitKind.Civilian))return false;
            }
            return true;
        }
        public int CampaignColumnRescued(int m)=>m>=0 && m<8 && campaign.columnArrivals?.Length==8?campaign.columnArrivals[m]:0;
        public int CampaignColumnSheltered(int m)=>m>=0 && m<8 && campaign.columnSheltered?.Length==8?campaign.columnSheltered[m]:0;
        void RecordColumns(int m){
            if(!ColumnsComplete)return;
            if(campaign.columnArrivals?.Length!=8)campaign.columnArrivals=new int[8];
            if(campaign.columnSheltered?.Length!=8)campaign.columnSheltered=new int[8];
            int arrived=0, sheltered=0;
            foreach(var l in state.lines){arrived+=l.arrived;sheltered+=l.sheltered;}
            campaign.columnArrivals[m]=arrived;campaign.columnSheltered[m]=sheltered;
        }
        void PrepareColumns(){
            if(state.columnVersion!=1 || state.lines!=null && state.lines.Length>0 || ChapterPhase!=2 || IsDuty)return;
            state.lines=new EvacuationLine[MarketColumn?1:2];
            for(int c=0;c<state.lines.Length;c++){
                var names=Manifest[MarketColumn?0:c+1];
                var l=new EvacuationLine{people=new int[names.Length],refuge=ColumnStart(c),marketInitialized=MarketColumn};state.lines[c]=l;
                for(int j=0;j<names.Length;j++){
                    var u=Spawn(UnitKind.Civilian,l.refuge+new Vector3(j%2,0,j/2),names[j],-1);
                    l.people[j]=u.id;Brain(u).auxiliary=true;Brain(u).column=c+1;
                    u.wounded=!MarketColumn && c==1 && j%2==1;if(u.wounded)u.hp=62;
                }
            }
            SoundNotice(MarketColumn?"青果店前の二人が付添を待っています":"北改札と救護室の二列が付添を待っています");
            EvacStorage.Write(CheckpointSlot,state);
        }
        bool SafeToLeave(int c){
            var l=Line(c);
            if(l.leg<1 || l.leg>2 || (!MarketColumn && Line(1-c).arrived==0))return false;
            foreach(var id in l.people){var u=Find(id);if(u.active && FlatSq(u.pos,l.refuge)>25)return false;}
            return true;
        }
        Unit ChooseColumnCrew(int c,int squad,int a,bool useControlled=true,int excluding=-1){
            if(useControlled && Controlled!=null)return Controlled;
            Unit best=null;float score=float.PositiveInfinity;
            foreach(var s in soldiers){
                if(s.id==excluding || (a==7 && Line(c).carrier==s.id) || !s.active || s.squad!=squad || Brain(s).cargo || Brain(s).escort>=0)continue;
                bool used=false;foreach(var l in state.lines)if((l!=Line(c) && l.lead==s.id) || l.operatorId==s.id || l.medic==s.id || l.pickup==s.id || (l.carrier==s.id && (l!=Line(c) || a==4 || a==6)))used=true;
                if(used || (a==4 && Line(c).lead==s.id && !Line(c).held))continue;
                float d=FlatSq(s.pos,ColumnActionPoint(c,a));
                if(d<score){score=d;best=s;}
            }
            return best;
        }
        public bool CanCommandColumn(int c,int a,int squad){
            var l=Line(c);if(!ColumnsActive || l==null || l.finished || a<0 || a>7 || squad<0 || squad>2)return false;
            bool puttingDown=a==7 && Controlled!=null && l.carrier==Controlled.id;
            if(a==7 && (StretcherPatient(c)==null || (l.pickup>=0 && !puttingDown)))return false;
            if(a==6 && (ColumnPatient(c)==null || MedicalSupplies<=0 || l.medic>=0))return false;
            if(a==2 && l.held || a==3 && (!l.held || l.route<0) || a==4 && (l.open || (l.operatorId>=0 && (Controlled==null || Controlled.id!=l.operatorId))) || a==5 && !SafeToLeave(c))return false;
            if(Controlled!=null){
                if(!Controlled.active || Controlled.vaultDuration>0 || (MarketColumn && (a==4 && l.lead==Controlled.id || (a<=1 || a==3) && l.operatorId==Controlled.id)))return false;
                if(!puttingDown){
                    var target=ColumnActionPoint(c,a);
                    if(FlatSq(Controlled.pos,target)>12.25f)return false;
                    if((a==4 || a==6 || a==7) && !geometry.LineClear(Controlled.pos+Vector3.up,target+Vector3.up))return false;
                    if(a==7 && (Brain(Controlled).cargo || Brain(Controlled).escort>=0 || ChapterHandsBusy(Controlled)))return false;
                }
                foreach(var other in state.lines)if(other!=l && (other.lead==Controlled.id || other.operatorId==Controlled.id || other.medic==Controlled.id || other.carrier==Controlled.id))return false;
            }
            return a==2 || a==5 || ChooseColumnCrew(c,squad,a)!=null;
        }
        public bool CommandColumn(int c,int a,int squad){
            if(!CanCommandColumn(c,a,squad))return false;
            var l=Line(c);
            if(l.marketMeeting && (a==0 || a==2 || a==5)){l.marketMeeting=false;l.operatorId=-1;}
            if(a==2){l.held=true;l.lead=-1;l.joined=false;}
            else if(a==5){
                foreach(var id in l.people){var u=Find(id);if(!u.active)continue;u.active=false;Brain(u).columnOutcome=2;l.sheltered++;}
                FinishColumn(l);
            }else{
                var worker=ChooseColumnCrew(c,squad,a);
                if(a==7){if(Controlled!=null)TransferStretcher(c,worker);else l.pickup=worker.id;}
                else if(a==6){if(Controlled!=null)TreatColumn(c);else l.medic=worker.id;}
                else if(a==4){
                    if(Controlled!=null)OpenColumnControl(c);else l.operatorId=worker.id;
                }else{
                    if(a<=1){if(MarketColumn && a!=l.route)l.marketStep=0;l.route=a;}
                    bool announced=!MarketColumn && c==0 && l.open;
                    l.lead=announced?-1:worker.id;l.held=false;l.joined=announced || FlatSq(worker.pos,ColumnPosition(c))<16;
                }
            }
            if(a!=7)SoundNotice(ColumnTitle(c)+"　"+ColumnActionLabel(c,a));
            else if(Controlled==null)SoundNotice(ColumnTitle(c)+"　担架の引き継ぎに隊員を派遣");
            Save();return true;
        }
        void TransferStretcher(int c,Unit worker){
            var l=Line(c);var patient=StretcherPatient(c);
            if(patient==null)return;
            if(l.carrier==worker.id){
                l.carrier=-1;l.carried=-1;l.held=true;l.lead=-1;l.joined=false;
                SoundNotice(patient.name+"を担架から下ろした"+(l.pickup>=0?"。交代の隊員が向かっています":""));return;
            }
            l.pickup=-1;l.carrier=worker.id;l.carried=patient.id;
            var axis=patient.pos-worker.pos;l.stretcherYaw=axis.sqrMagnitude>.04f?Mathf.Atan2(axis.x,axis.z)*Mathf.Rad2Deg:worker.yaw;
            SoundNotice(worker.name+"が"+patient.name+"の担架を引き継いだ");
        }
        void TreatColumn(int c){
            var l=Line(c);l.medic=-1;
            var patient=ColumnPatient(c);if(patient==null || state.medPacks<1)return;
            state.medPacks--;patient.wounded=false;Brain(patient).injured=false;patient.hp=patient.maxHp;
            SoundNotice(patient.name+"の手当てを完了");
        }
        void OpenColumnControl(int c){
            var l=Line(c);l.open=true;l.operatorId=-1;
            if(MarketColumn)l.marketOpenedAt=Elapsed;
            if(!MarketColumn && c==0 && !l.held){l.lead=-1;l.joined=true;}
            SoundNotice(ColumnActionLabel(c,4)+"　完了");
        }
        void FinishColumn(EvacuationLine l){
            l.finished=true;l.held=true;l.lead=-1;l.operatorId=-1;l.carrier=-1;l.carried=-1;l.pickup=-1;l.medic=-1;
            if(l.arrived>0){state.volunteers++;state.depotRounds+=l.arrived*6;}
            EvacStorage.Write(CheckpointSlot,state);Save();
        }
        bool ReachColumnTask(Unit worker,Vector3 point,float dt)
        {
            // A counter or closed door can be thinner than interaction distance.
            // Continue toward the actual walkable contact until both sides share clear sight.
            if(FlatSq(worker.pos,point)<6 && geometry.LineClear(worker.pos+Vector3.up,point+Vector3.up))return true;
            Walk(worker,point,4,dt);
            return false;
        }
        bool ColumnCrew(Unit u,float dt){
            if(!ColumnsActive || ColumnsComplete)return false;
            for(int c=0;c<ColumnCount;c++){
                var l=Line(c);if(l.finished)continue;
                if(l.pickup==u.id){
                    var p=StretcherPatient(c);
                    if(p==null)l.pickup=-1;
                    else if(ReachColumnTask(u,p.pos,dt))TransferStretcher(c,u);
                    return true;
                }
                if(l.carrier==u.id && l.lead!=u.id){
                    var guide=Find(l.lead);
                    if(!l.held && guide!=null && guide.active && ColumnPassable(c) && FlatSq(guide.pos,u.pos)>2)Walk(u,guide.pos,3.35f,dt);
                    return true;
                }
                if(l.medic==u.id){var p=ColumnPatient(c);if(p==null)l.medic=-1;else if(ReachColumnTask(u,p.pos,dt))TreatColumn(c);return true;}
                if(l.operatorId==u.id){
                    if(ReachColumnTask(u,ColumnControlPoint(c),dt))OpenColumnControl(c);
                    return true;
                }
                if(l.lead!=u.id || l.held)continue;
                var brain=Brain(u);
                if((!MarketWaiting(u.id) || WaitingAtMarketQueue(l)) && !MarketPassingImpact(l) && !ColumnHandsBusy(u) && brain.fireDelay==0 && u.reload<=0 && u.ammo>0){var threat=NearestThreat(u.pos,16);if(threat!=null)HitShot(u,threat,(threat.pos-u.pos).normalized,true);}
                if(u.ammo==0)StartReload(u);
                if(!MarketColumn && l.leg==1 && l.route==1){
                    foreach(int id in l.people){
                        var rider=Find(id);
                        if(!rider.active || !rider.wounded || Brain(rider).columnStairs || id==l.people[1])continue;
                        bool atStairs=rider.pos.z<=52 || FlatSq(rider.pos,Mark(-9,55))<=6;
                        if(atStairs && FlatSq(u.pos,rider.pos)>=12){Walk(u,rider.pos,3.8f,dt);return true;}
                    }
                }
                var tail=ColumnPosition(c);float far=0;
                foreach(var id in l.people){var p=Find(id);if(!p.active || (l.leg==1 && (Brain(p).columnLifted || Brain(p).columnStairs)))continue;float d=FlatSq(u.pos,p.pos);if(d>far){far=d;tail=p.pos;}}
                if(!l.joined || far>36){
                    Walk(u,tail,4,dt);
                    if(far<16)l.joined=true;
                }else if(ColumnPassable(c) && !MarketWaiting(u.id))Walk(u,ColumnDestination(c),3.8f,dt);
                return true;
            }
            return false;
        }
        void StepColumnPerson(Unit u,float dt){
            int c=Brain(u).column-1;var l=Line(c);
            if(l!=null && !l.finished && l.carried==u.id && Find(l.carrier) is Unit bearer && bearer.active){
                AdvanceStretcher(l,u,bearer,dt);
                if(l.leg==1 && l.route==1 && u.pos.z<=55)Brain(u).columnStairs=true;
                if(l.leg==1 && l.route==0 && !Brain(u).columnLifted && state.liftCount>0 && FlatSq(u.pos,ColumnDestination(c))<7){state.liftCount--;Brain(u).columnLifted=true;}
                return;
            }
            if(l==null || l.held || l.finished || l.route<0)return;
            bool committed=l.leg==1 && (Brain(u).columnLifted || Brain(u).columnStairs);
            if(committed){Walk(u,MemberDestination(c,u),u.wounded?2.65f:3.15f,dt);return;}
            if(!ColumnPassable(c))return;
            var leader=Find(l.lead);
            bool broadcast=!MarketColumn && c==0 && l.open;
            if(!broadcast && (leader==null || !leader.active))return;
            if(leader!=null && FlatSq(u.pos,leader.pos)<16)l.joined=true;
            if(!l.joined || (!broadcast && FlatSq(u.pos,leader.pos)>64))return;
            if(MarketWaiting(u.id))return;
            var goal=MemberDestination(c,u);
            if(!MarketColumn && l.leg==1 && l.route==1 && u.wounded && !Brain(u).columnStairs){
                var stair=Mark(-9,55);
                if(FlatSq(u.pos,stair)>6 && u.pos.z>52)goal=stair;
                else {
                    bool supported=leader!=null && leader.active && FlatSq(u.pos,leader.pos)<16;
                    foreach(int id in l.people){
                        var peer=Find(id);
                        if(peer.active && !peer.wounded && FlatSq(peer.pos,u.pos)<16)supported=true;
                    }
                    if(!supported || u.id==l.people[1])return;
                    Brain(u).columnStairs=true;
                }
            }
            if(!MarketColumn && !broadcast && FlatSq(u.pos,leader.pos)>4 && FlatSq(u.pos,goal)<FlatSq(leader.pos,goal))goal=leader.pos;
            Walk(u,goal,u.wounded?2.65f:3.15f,dt);
            if(!MarketColumn && l.leg==1 && l.route==0 && !Brain(u).columnLifted &&
                FlatSq(u.pos,ColumnDestination(c))<7 && state.liftCount>0){
                state.liftCount--;Brain(u).columnLifted=true;
            }
        }
        Vector3 LimitStretcherPush(Unit bearer,Vector3 proposed)
        {
            if(!ColumnHandsBusy(bearer))return proposed;
            var p=Find(ColumnCarriedId(1));if(p==null)return proposed;
            Vector3 movement=proposed-bearer.pos;
            if(movement.sqrMagnitude<.000001f)return proposed;
            // A bearer can pivot in place even when the front wheels meet a wall.
            Vector3 wheel=WalkingMap.Move(p.pos,p.pos+movement);
            float progress=Mathf.Clamp01(Vector3.Dot(wheel-p.pos,movement)/movement.sqrMagnitude);
            if(FlatSq(proposed,p.pos)>4.8f)progress=Mathf.Min(progress,.35f);
            return Vector3.Lerp(bearer.pos,proposed,progress);
        }
        void AdvanceStretcher(EvacuationLine l,Unit patient,Unit bearer,float dt)
        {
            float targetYaw=Mathf.MoveTowardsAngle(l.stretcherYaw,bearer.yaw,165*dt);
            var heading=Quaternion.Euler(0,targetYaw,0)*Vector3.forward;
            // Test the whole length so the front never swings through a doorway jamb.
            var reach=WalkingMap.Move(bearer.pos,bearer.pos+heading*1.45f);
            var before=patient.pos;
            patient.pos=WalkingMap.Move(before,Vector3.MoveTowards(before,reach,5.5f*dt));
            patient.moving=FlatSq(before,patient.pos)>.000001f;
            Vector3 actual=patient.pos-bearer.pos;
            if(actual.sqrMagnitude>.03f)l.stretcherYaw=Mathf.Atan2(actual.x,actual.z)*Mathf.Rad2Deg;
            else l.stretcherYaw=targetYaw;
            patient.yaw=l.stretcherYaw;
        }
        void CheckColumns(){
            if(!ColumnsActive || ColumnsComplete)return;
            for(int c=0;c<ColumnCount;c++){
                var l=Line(c);if(l.finished)continue;
                if(l.pickup>=0 && Find(l.pickup)?.active!=true)l.pickup=-1;
                if(l.carrier>=0 && (Find(l.carrier)?.active!=true || Find(l.carried)?.active!=true)){l.carrier=-1;l.carried=-1;}
                if(l.medic>=0 && Find(l.medic)?.active!=true)l.medic=-1;
                if(l.operatorId>=0 && Find(l.operatorId)?.active!=true)l.operatorId=-1;
                if(l.lead>=0 && Find(l.lead)?.active!=true){l.lead=-1;l.held=true;l.joined=false;}
                bool live=false,all=true;
                var goal=ColumnDestination(c);
                foreach(var id in l.people){var u=Find(id);if(!u.active)continue;live=true;if(FlatSq(u.pos,MemberDestination(c,u))>(MarketColumn?.44f:7) || (!MarketColumn && l.leg==1 && l.route==0 && !Brain(u).columnLifted && !Brain(u).columnStairs))all=false;}
                if(!live){FinishColumn(l);continue;}
                if(l.held || !all || !l.joined || WaitingAtMarketQueue(l))continue;
                if(MarketColumn && AdvanceMarketStop(l))continue;
                l.refuge=goal;l.leg++;
                if(l.leg>=3){
                    foreach(var id in l.people){var u=Find(id);if(!u.active)continue;u.active=false;Brain(u).columnOutcome=1;l.arrived++;}
                    FinishColumn(l);
                }else if(!MarketColumn && l.leg==1){
                    l.held=true;l.lead=-1;l.joined=false;EvacStorage.Write(CheckpointSlot,state);
                    SoundNotice(ColumnTitle(c)+"が"+ColumnCurrentStop(c)+"に集合。次の進路を指定");
                }
            }
        }
    }
}
