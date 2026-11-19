using System;
using UnityEngine;

namespace Evac
{
    internal enum DutyGoal { DispatchMedicine, RecoverPatients, SecureLoading, FixTruck, TransferGoods, FindShelter, DrainAndBoard, Muster, CheckShed, ReturnManifest }

    internal sealed class DutyStage
    {
        internal readonly SectorDef sector;
        internal readonly DutyGoal goal;
        internal readonly Vector2 assembly, gate, works, cache;
        internal readonly int minimum, wounded;
        internal readonly string required;
        internal readonly string[] people;
        internal DutyStage(string name, string instruction, DutyGoal goal, FieldWork work, Vector2 assembly, Vector2 gate,
            Vector2 works, Vector2 cache, int minimum, int wounded, string required, params string[] people)
        {
            sector=new SectorDef(name,work,0,instruction);
            this.goal=goal;this.assembly=assembly;this.gate=gate;this.works=works;this.cache=cache;
            this.minimum=minimum;this.wounded=wounded;this.required=required;this.people=people;
        }
    }

    internal sealed class DutyPlan
    {
        internal readonly string title, brief, ending;
        internal readonly DutyStage[] stages;
        internal readonly int capacity, quota;
        DutyPlan(string title,string brief,string ending,params DutyStage[] stages)
        {
            this.title=title;this.brief=brief;this.ending=ending;this.stages=stages;
            foreach(var s in stages){capacity+=s.people.Length;quota+=s.minimum;}
        }
        static Vector2 P(float x,float z)=>new Vector2(x,z);
        internal static readonly DutyPlan[] All =
        {
            new DutyPlan("夜間診療の送り","救急車は一台。薬を運ぶか救護所を建てて患者を受け入れ、診療所の市川さんを搬送します。",
                "夜間診療班が患者と付き添いを病院へ送り届けました。",
                new DutyStage("薬の受け入れ","薬箱を補給所へ運ぶか、補給所に救護所を建設",DutyGoal.DispatchMedicine,FieldWork.Haul,
                    P(-8,-2),P(-5,-5),P(4,-12),P(-11,7),0,0,null),
                new DutyStage("診療所の玄関","市川さんに肩を貸し、もう一人の患者と救急車へ",DutyGoal.RecoverPatients,FieldWork.Triage,
                    P(10,9),P(6,0),P(6,-4),P(-10,7),2,1,"患者・市川","患者・市川","患者・安部"),
                new DutyStage("通院バス停","警備班で乗り換え口を確保し、付き添いを四人乗せる",DutyGoal.SecureLoading,FieldWork.Screen,
                    P(-11,16),P(-5,3),P(-7,4),P(-8,-3),4,1,null,"付き添い・川島","付き添い・東","付き添い・村山","付き添い・大川","付き添い・長井")),
            new DutyPlan("故障車の代走","故障した送迎車の扉を開けます。荷物を運び直すか連絡橋を直し、運転手と乗客を代車へ。",
                "代車が出発し、故障車の乗客と運転手が待機所に到着しました。",
                new DutyStage("車庫の故障車","整備班を故障車へ派遣し、固着した扉を解除",DutyGoal.FixTruck,FieldWork.Repair,
                    P(-10,14),P(-5,6),P(-11,10),P(10,8),0,0,null),
                new DutyStage("積み替え口","資材を二箱運ぶか、設備地点で連絡橋を修理。荷役係を二人収容",DutyGoal.TransferGoods,FieldWork.Haul,
                    P(10,15),P(3,3),P(-8,3),P(11,8),2,0,null,"荷役係・福井","荷役係・植田","荷役係・林"),
                new DutyStage("代車の乗降場","乗降場を警戒し、負傷した運転手を含む三人を代車へ",DutyGoal.SecureLoading,FieldWork.Screen,
                    P(-9,17),P(-3,5),P(-7,4),P(6,8),3,1,"運転手・北村","運転手・北村","乗客・松井","乗客・遠藤","乗客・平野")),
            new DutyPlan("終電後の捜索","閉駅後のホームで人を捜します。待合室を訪ねるか非常放送を使って居場所を確認し、夜行の救援列車へ。",
                "最後の車掌が乗り込み、救援列車が夜のホームを離れました。",
                new DutyStage("閉鎖された待合室","誘導班が集合地点の待合室を調べるか、駅の非常放送で呼びかける",DutyGoal.FindShelter,FieldWork.Gather,
                    P(-11,18),P(-7,10),P(-11,18),P(8,0),0,0,null),
                new DutyStage("冠水した連絡路","排水と昇降機に通電し、地下に残る利用客を二人収容",DutyGoal.DrainAndBoard,FieldWork.Drain,
                    P(8,15),P(2,4),P(-7,-2),P(-9,6),2,0,null,"利用客・黒木","利用客・河合","利用客・長谷"),
                new DutyStage("乗務員通路","負傷した車掌を支え、乗務員を救援列車へ",DutyGoal.RecoverPatients,FieldWork.Triage,
                    P(-10,22),P(-4,9),P(-5,3),P(5,4),2,1,"車掌・長岡","車掌・長岡","乗務員・柳","乗務員・町田")),
            new DutyPlan("基地の最終点呼","点呼簿と本人を照合し、見回りに出た班長を捜します。点呼簿を届けて最後の人員輸送車を出してください。",
                "点呼簿と乗車名簿がそろい、基地の当直を引き継ぎました。",
                new DutyStage("西詰所の点呼","西詰所の当直者二人を車へ案内",DutyGoal.Muster,FieldWork.Gather,
                    P(-10,13),P(-3,2),P(-6,6),P(9,3),2,0,"当直員・小林","当直員・小林","当直員・中田"),
                new DutyStage("巡回小屋の確認","警備班が通路を確保し、誘導班が集合地点の巡回小屋を調べる",DutyGoal.CheckShed,FieldWork.Screen,
                    P(10,18),P(3,7),P(10,18),P(-10,3),0,0,null),
                new DutyStage("点呼簿の返却","資材地点の点呼簿を補給所へ届け、班長を含む三人を乗せる",DutyGoal.ReturnManifest,FieldWork.Haul,
                    P(8,12),P(1,1),P(-3,-4),P(-10,12),3,1,"班長・石川","班長・石川","巡回員・三浦","巡回員・丹羽","巡回員・仁科"))
        };
    }

    [Serializable]
    internal class DutyRecord
    {
        public bool[] completed=new bool[4];
    }

    public partial class GameSim
    {
        DutyRecord dutyLog;
        public bool IsDuty => state.duty;
        public int DutyIndex => IsDuty ? state.index/2 : -1;
        DutyPlan CurrentDuty => DutyPlan.All[DutyIndex];
        DutyStage DutyStage => CurrentDuty.stages[Sector];
        public static string DutyName(int index)=>DutyPlan.All[Mathf.Clamp(index,0,3)].title;
        public static string DutyBrief(int index)=>DutyPlan.All[Mathf.Clamp(index,0,3)].brief;
        public string DutyEnding => IsDuty ? CurrentDuty.ending : "";
        public bool DutyCompleted(int index)=>index>=0 && index<4 && dutyLog.completed[index];
        public bool HasDutySave => EvacStorage.Exists("duty-suspend");
        string CheckpointSlot => IsDuty ? "duty-checkpoint" : "checkpoint";
        public void StartDuty(int district,Difficulty difficulty)=>StartOperation(Mathf.Clamp(district,0,3)*2,difficulty,true);
        public bool LoadDuty()=>Restore("duty-suspend");
        RoutePlan DutyRoute(int stage)
        {
            var map=BasePlan;
            var s=CurrentDuty.stages[stage];
            return new RoutePlan(map.task,CurrentDuty.title,map.district,CurrentDuty.brief,CurrentDuty.capacity,CurrentDuty.quota,
                s.wounded,new Vector2(map.entrance.x,map.entrance.z),s.assembly,s.gate,new Vector2(map.exit.x,map.exit.z),
                new Vector2(map.depot.x,map.depot.z),s.cache,s.works,map.waveInterval);
        }
        int DutyQuotaThroughStage()
        {
            int total=0;
            for(int i=0;i<=Sector;i++)total+=CurrentDuty.stages[i].minimum;
            return total;
        }
        string CargoLabel => !IsDuty ? "資材" : DutyStage.goal==DutyGoal.ReturnManifest ? "点呼簿" :
            DutyStage.goal==DutyGoal.DispatchMedicine ? "薬箱" : "荷物";
        bool DutyAlternativeBridge => IsDuty && DutyStage.goal==DutyGoal.TransferGoods;
        bool DutySearch => IsDuty && (DutyStage.goal==DutyGoal.FindShelter || DutyStage.goal==DutyGoal.CheckShed);
        void CheckDutySite()
        {
            if(!DutySearch || state.dutyFound)return;
            if(DutyStage.goal==DutyGoal.FindShelter && AlarmSerial>state.dutyAlarmBaseline)
            {
                state.dutyFound=true;return;
            }
            foreach(var u in soldiers)
            {
                if(!u.active || u==Controlled || !SectorDispatched(u.squad) || OrderFor(u.squad)!=SquadOrder.Guide)continue;
                if(FlatSq(u.pos,ActiveAssembly)<5 && FlatSq(DestinationFor(u.squad),ActiveAssembly)<16)
                {state.dutyFound=true;return;}
            }
        }
        bool AtDutySearch(Unit u)=>DutySearch && !state.dutyFound && u!=null && FlatSq(u.pos,ActiveAssembly)<6 &&
            geometry.LineClear(u.pos+Vector3.up,ActiveAssembly+Vector3.up);
        string DutyObjective()
        {
            var stage=DutyStage;
            switch(stage.goal)
            {
                case DutyGoal.DispatchMedicine:
                    if(Site==1)return "救護所を建設　"+Mathf.RoundToInt(Construction*100)+"%";
                    break;
                case DutyGoal.FixTruck:
                    return "故障車の扉を解除　"+Mathf.RoundToInt(state.sectionRepair*100)+"%";
                case DutyGoal.TransferGoods:
                    if(state.dutyBridge && state.sectionRepair<1)
                        return "連絡橋を修理　"+Mathf.RoundToInt(state.sectionRepair*100)+"%";
                    if(!state.dutyBridge && SectorTrips<2)
                        return "補給所へ資材を輸送　"+SectorTrips+"/2　連絡橋の修理でも通行可";
                    break;
                case DutyGoal.DrainAndBoard:
                    if((PowerMask&1)==0 || Water>=.73f)return "排水回路に通電　水位 "+Mathf.RoundToInt(Water*100)+"%";
                    if((PowerMask&2)==0)return "昇降機に通電して地下の利用客を迎える";
                    break;
                case DutyGoal.CheckShed:
                    if(state.screened && !state.dutyFound)return "通路を確保。誘導班または現場の隊員で巡回小屋を確認";
                    if(!state.screened && state.dutyFound)return "小屋を確認。警備班を通路へ";
                    break;
                case DutyGoal.ReturnManifest:
                    if(SectorTrips<1)return "資材地点の点呼簿を補給所へ運ぶ";
                    break;
            }
            return stage.sector.call;
        }
        bool DutyStageDone()
        {
            switch(DutyStage.goal)
            {
                case DutyGoal.DispatchMedicine: return SectorTrips>=1 || (state.built && Site==1);
                case DutyGoal.FixTruck: return state.sectionRepair>=1;
                case DutyGoal.FindShelter: return state.dutyFound;
                case DutyGoal.CheckShed: return state.dutyFound && state.screened;
            }
            if(state.sectionBoarded<DutyStage.minimum)return false;
            if(DutyStage.required==null)return true;
            foreach(var u in state.units)
                if(u.kind==UnitKind.Civilian && u.name==DutyStage.required && u.boarded)return true;
            return false;
        }
        bool DutyLossPreventsCompletion(Unit casualty)
        {
            if(!IsDuty || Brain(casualty).sector!=Sector)return false;
            if(casualty.name==DutyStage.required)return true;
            int possible=state.sectionBoarded;
            foreach(var u in state.units)
                if(u.active && IsCivilian(u) && Brain(u).sector==Sector)possible++;
            return possible<DutyStage.minimum;
        }
        void FinishDuty()
        {
            dutyLog.completed[DutyIndex]=true;
            EvacStorage.Write("duty-record",dutyLog);
            SoundNotice(CurrentDuty.ending);Save();
        }
    }
}
