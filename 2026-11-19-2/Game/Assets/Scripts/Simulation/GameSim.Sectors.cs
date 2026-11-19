using UnityEngine;

namespace Evac
{
    internal enum FieldWork { Gather, Haul, Repair, HaulAndRepair, Screen, Lift, Drain, Generator, Triage }
    internal sealed class SectorDef
    {
        internal readonly string name, call;
        internal readonly FieldWork work;
        internal readonly int side;
        internal SectorDef(string name, FieldWork work, int side, string call)
        {this.name=name;this.work=work;this.side=side;this.call=call;}

        internal static readonly SectorDef[][] Operations =
        {
            new[] {
                new SectorDef("青果店前",FieldWork.Gather,0,"青果店の店先に最初の住民が集まっています"),
                new SectorDef("裏通り",FieldWork.Gather,1,"裏通りから呼び声。班を向かわせてください"),
                new SectorDef("バス停",FieldWork.Triage,2,"バス停に歩けない人がいます。肩を貸してください") },
            new[] {
                new SectorDef("薬局",FieldWork.Gather,0,"薬局の奥から人影。誘導班を派遣してください"),
                new SectorDef("西口",FieldWork.Screen,1,"西口に群れが接近。警備班で合流点を確保"),
                new SectorDef("屋台裏",FieldWork.Triage,3,"屋台の裏に負傷者。隊員の助けが必要です"),
                new SectorDef("商店会館",FieldWork.Repair,2,"会館の非常扉が動きません。整備班を現場へ") },
            new[] {
                new SectorDef("荷受け場",FieldWork.Haul,0,"荷受け場の橋材を集積所へ運んでください"),
                new SectorDef("冷蔵棟",FieldWork.Repair,2,"冷蔵棟の扉を修理して中の作業員を誘導"),
                new SectorDef("搬入口",FieldWork.Screen,3,"搬入口に人が集中しています。警備班を合流点へ"),
                new SectorDef("西側桟橋",FieldWork.Haul,1,"桟橋で荷車が脱輪しました。資材を運んで通路を直してください") },
            new[] {
                new SectorDef("整備棟",FieldWork.Repair,0,"故障した巻き上げ機を直してください"),
                new SectorDef("工具庫",FieldWork.Haul,3,"工具庫から支柱を集積所へ運んでください"),
                new SectorDef("仮眠室",FieldWork.Triage,2,"仮眠室に負傷した夜勤者。迎えをお願いします"),
                new SectorDef("北門",FieldWork.Screen,1,"北門に群れ。警備班で退路を確保"),
                new SectorDef("出荷口",FieldWork.HaulAndRepair,4,"積み込み橋が故障。交換材を運んで修復してください") },
            new[] {
                new SectorDef("地下改札",FieldWork.Lift,0,"地下改札から昇降機へ。排水と昇降機の電源を確認"),
                new SectorDef("西側階段",FieldWork.Screen,1,"西側階段で待機中。合流点が安全になれば移動できます"),
                new SectorDef("待合室",FieldWork.Triage,3,"待合室に一人では歩けない乗客がいます。隊員を向かわせてください"),
                new SectorDef("機械室",FieldWork.Generator,2,"予備電源の復旧が必要です。整備班を機械室へ"),
                new SectorDef("東地下道",FieldWork.Drain,4,"地下道に水が流入。排水しながら住民を昇降機へ") },
            new[] {
                new SectorDef("地下入口",FieldWork.Drain,0,"地下入口が冠水しています。排水を優先"),
                new SectorDef("連絡口",FieldWork.Haul,2,"中継ケーブルを確保し、連絡口の電源を接続"),
                new SectorDef("商業通路",FieldWork.Screen,1,"商業通路に群れが流入。警備班を合流点へ"),
                new SectorDef("避難階段",FieldWork.Triage,4,"階段に歩けない乗客。支えて車内へ"),
                new SectorDef("保守通路",FieldWork.Generator,3,"保守通路の制御盤を復旧してください"),
                new SectorDef("地下広場",FieldWork.Drain,0,"地下広場で浸水。最後の乗客を迎えに戻ってください") },
            new[] {
                new SectorDef("中継所",FieldWork.HaulAndRepair,0,"中継所の部材を回収し、通信設備を復旧"),
                new SectorDef("河川敷",FieldWork.Screen,3,"河川敷で退路を確保。車両まで護衛します"),
                new SectorDef("観測小屋",FieldWork.Triage,2,"観測小屋にけが人。隊員を派遣してください"),
                new SectorDef("艇庫",FieldWork.Haul,1,"艇庫の橋板を集積所へ搬送"),
                new SectorDef("陸橋下",FieldWork.Repair,4,"陸橋下の車止めを修理。最後の住民が待機中") },
            new[] {
                new SectorDef("車両基地",FieldWork.HaulAndRepair,0,"信号設備を復旧し、基地に最初の車列を迎えてください"),
                new SectorDef("西待避所",FieldWork.Screen,1,"西待避所の合流点を確保"),
                new SectorDef("工場跡",FieldWork.Haul,4,"工場跡の資材で車列に補給"),
                new SectorDef("救護テント",FieldWork.Triage,2,"救護テントに残る人を運んでください"),
                new SectorDef("堤防下",FieldWork.Repair,3,"堤防下の門を復旧してください"),
                new SectorDef("終点",FieldWork.Screen,0,"終点に最後の一団。警備班で進路を守ってください") }
        };
    }

    public partial class GameSim
    {
        RoutePlan[] districtPlans;
        RoutePlan activePlan;
        MissionDef activeMission;
        RoutePlan BasePlan => RoutePlan.All[state.index];
        SectorDef SectorData => IsDuty ? DutyStage.sector : SectorDef.Operations[state.index][state.sector];
        public int Sector => state.sector;
        public int SectorCount => IsDuty ? CurrentDuty.stages.Length : SectorDef.Operations[state.index].Length;
        public string SectorName => SectorData.name;
        public int SectorGoal => IsDuty ? DutyQuotaThroughStage() : (Route.quota*(Sector+1)+SectorCount-1)/SectorCount;
        int GroupSize(int sector) => Route.population*(sector+1)/SectorCount - Route.population*sector/SectorCount;
        public Vector3 ActiveAssembly => Route.assembly;
        public Vector3 ActiveGate => Route.gate;
        public Vector3 ActiveWorks => Route.works;
        public Vector3 ActiveCache => Route.cache;
        public Vector3 ActiveEntrance => Route.entrance;
        public Vector3 ActiveDepot => Route.depot;
        public Vector3 ActiveExit => Route.exit;

        RoutePlan MakeRoute(int sector)
        {
            if(IsDuty)return DutyRoute(sector);
            var b=BasePlan;
            int side=SectorDef.Operations[state.index][sector].side;
            if(side==0)return b;
            float sign=b.assembly.x<0?-1:1;
            Vector2 assembly=side==1?new Vector2(-sign*15,17):side==2?new Vector2(sign*15,-5):
                side==3?new Vector2(-sign*14,-4):new Vector2(sign*12,24);
            Vector2 gate=side==1?new Vector2(-sign*7,6):side==2?new Vector2(sign*7,-11):
                side==3?new Vector2(-sign*5,-9):new Vector2(sign*5,10);
            Vector2 threat=side==1?new Vector2(-sign*17,30):side==2?new Vector2(sign*20,11):
                side==3?new Vector2(-sign*20,12):new Vector2(sign*6,32);
            assembly.x=Mathf.Clamp(assembly.x,-12f,12f);
            threat.x=Mathf.Clamp(threat.x,-14f,14f);
            Vector2 works=Vector2.Lerp(assembly,gate,.55f)+Vector2.right*2;
            Vector2 cache=assembly+new Vector2(-sign*2,-3);
            cache.x=Mathf.Clamp(cache.x,-12f,12f);
            return new RoutePlan(b.task,b.title,b.district,b.briefing,b.population,b.quota,b.wounded,threat,assembly,gate,
                new Vector2(b.exit.x,b.exit.z),new Vector2(b.depot.x,b.depot.z),cache,works,b.waveInterval);
        }
        void SetRoute()
        {
            districtPlans=null;
            activePlan=MakeRoute(Sector);
            geometry=new WorldGeometry(state.index,activePlan,FleetEnabled);
            alarmSite=Ground(AlarmSites[AlarmDistrict]);
            for(int i=0;i<state.units.Count;i++)
            {
                var unit=state.units[i];
                bool crossing=unit.vaultDuration>0 && unit.vaultDuration<=.7f && unit.vaultTime>=0 && unit.vaultTime<unit.vaultDuration &&
                    (unit.vaultFrom-unit.vaultTo).sqrMagnitude<=3.61f*3.61f && (geometry.Clamp(unit.vaultTo)-unit.vaultTo).sqrMagnitude<.001f;
                if(!crossing){unit.vaultDuration=0;unit.pos=geometry.Clamp(unit.pos);}
                state.actors[i].hasPath=false;
            }
            activeMission=new MissionDef(state.index,activePlan);
        }
        void OpenSector(bool initial)
        {
            SetRoute();
            state.dutyFound=false;state.dutyBridge=false;state.dutyAlarmBaseline=AlarmSerial;
            state.sectionBoarded=0;state.sectionDelivered=state.delivered;
            state.sectionRepair=0;state.security=0;state.screened=false;
            state.crates+=RequiredTrips+1;
            if(SectorData.work==FieldWork.Drain)state.water=Mathf.Max(state.water,.9f);
            if(SectorData.work==FieldWork.Triage)state.sectionAssists=0;
            int count=IsDuty?DutyStage.people.Length:GroupSize(Sector);
            int injuredCount=IsDuty?DutyStage.wounded:SectorData.work==FieldWork.Triage?Mathf.Max(1,count/2):Mathf.Min(count/4,2);
            for(int i=0;i<count;i++)
            {
                float x=(i%5-2)*1.2f+state.Draw()*.4f;
                float z=(i/5-1)*1.2f+state.Draw()*.4f;
                int number=Route.population*Sector/SectorCount+i+1;
                string name=IsDuty?DutyStage.people[i]:"住民 "+number;
                bool inShelter=!IsDuty && state.index>0 && i>=count-Mathf.Max(1,count/5);
                var shelter=inShelter ? ApproachBlocks.FieldStation(state.index,Sector) : Route.assembly;
                var c=Spawn(UnitKind.Civilian,shelter+new Vector3(x,0,z),name,-1);
                var a=Brain(c);a.sector=Sector;a.fieldShelter=inShelter;
                // A late evacuation can put one of its patients at the satellite stop.
                bool remotePatient=FleetEnabled && state.index>=6 && injuredCount>=2;
                a.injured=i<injuredCount-(remotePatient?1:0) || (remotePatient && i==count-1);c.wounded=a.injured;
                a.personalGate=Route.gate+new Vector3((i%5-2)*.43f,0,(i%3-1)*.25f);
            }
            ApplyDistrictRoute();
            UseChapterSupplies();
            if(!initial)
            {
                state.waveCount++;SpawnWave(1+(int)Level+state.index/3);
                state.waveIn=Mathf.Max(6,state.waveIn);
                SoundNotice(SectorName+"　"+SectorData.call);
                EvacStorage.Write(CheckpointSlot,state);
            }
        }
        bool HandleSector()
        {
            if((IsDuty || ChapterPhase==2) && IsSectorCleared() && Sector+1<SectorCount)
            {
                state.sector++;OpenSector(false);return true;
            }
            return false;
        }
        bool IsSectorCleared()
        {
            if(IsDuty)return DutyStageDone();
            if(DistrictOutcome(Sector)==0)return false;
            if(Boarded>=SectorGoal && state.sectionBoarded>0 && (!NeedsTriage || state.sectionAssists>0))return true;
            // A dead local group cannot fill its original share. Later districts
            // can make up the difference, but the final vehicle quota still applies.
            if(state.losses==0 || (Sector==SectorCount-1 && Boarded<Mission.quota))return false;
            foreach(var c in state.units)
                if(c.active && IsCivilian(c) && !Brain(c).auxiliary && Brain(c).sector==Sector)return false;
            return true;
        }
        bool NeedsScreen => SectorData.work==FieldWork.Screen;
        bool NeedsTriage => SectorData.work==FieldWork.Triage;
        bool SectorDispatched(int squad) => state.squads[squad].sector==Sector && state.squads[squad].assigned;
        void ScreenArea(float dt)
        {
            if(!NeedsScreen || state.screened)return;
            foreach(var s in soldiers)
            {
                if(!s.active || FlatSq(s.pos,Route.gate)>5.5f*5.5f)continue;
                if(s!=Controlled && (OrderFor(s.squad)!=SquadOrder.Guard || !SectorDispatched(s.squad)))continue;
                if(NearestThreat(Route.gate,4)!=null)return;
                state.security+=dt;
                if(state.security>=3) {state.screened=true;SoundNotice("合流点を確保。避難を再開");}
                return;
            }
        }
    }
}
