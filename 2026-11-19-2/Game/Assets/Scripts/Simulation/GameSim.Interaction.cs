using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        enum ActionKind { None, Release, Lift, Resuscitate, Retrieve, Deliver, Fix, Treat, Construct, Restock, Optional, Alarm, CheckDuty, RepairBridge, District, PatchRoad, ChapterStation, ChapterSupply }
        ActionKind Context(Unit u,out Unit nearby)
        {
            nearby=null;
            if(u==null || u.vaultDuration>0 || u.dodgeTime>0 || Result!=SimResult.Active)return ActionKind.None;
            var a=Brain(u);
            if(a.escort<0 && !a.cargo && AtChapter(u))return ActionKind.ChapterStation;
            if(ChapterHandsBusy(u))return ActionKind.None;
            if(a.escort>=0)return ActionKind.Release;
            if(RequestInteraction(u))return ActionKind.Optional;
            if(a.requestCargo)return ActionKind.None;
            if(a.cargo)return FlatSq(u.pos,Route.depot)<12.25f?ActionKind.Deliver:ActionKind.None;
            float shortest=2.9f*2.9f;
            foreach(var c in state.units)
            {
                if(c==u || c.boarded || c.kind==UnitKind.Infected || IsSearchResident(c) || IsChapterResident(c) || IsChapterLiaison(c))continue;
                bool patient=IsSoldier(c)?!c.active && u.medkits>0:c.active && Brain(c).escort<0 && Brain(c).injured;
                if(!patient)continue;
                float d=FlatSq(c.pos,u.pos);
                if(d<shortest){shortest=d;nearby=c;}
            }
            if(nearby!=null)
            {
                int district=NearbyDistrict(u);
                if(FieldEventLive(district))
                {
                    float handover=DistrictProgress(district)==0 ?
                        Mathf.Min(FlatSq(u.pos,IncidentConsole(district,false)),FlatSq(u.pos,IncidentConsole(district,true))) :
                        FlatSq(u.pos,DistrictPosition(district));
                    if(handover<1.5f && handover<shortest)return ActionKind.District;
                }
                return IsSoldier(nearby)?ActionKind.Resuscitate:ActionKind.Lift;
            }
            if(AtFleetBlock(u))return ActionKind.PatchRoad;
            if(AtDutySearch(u))return ActionKind.CheckDuty;
            if(DutyAlternativeBridge && state.sectionRepair<1 && FlatSq(u.pos,ActiveWorks)<9)return ActionKind.RepairBridge;
            if(AtAlarm(u))return ActionKind.Alarm;
            if(NearbyDistrict(u)>=0)return ActionKind.District;
            if(((NeedsRepair && state.sectionRepair<1) || (Rail && !Repaired)) && FlatSq(u.pos,Route.works)<12.25f)return ActionKind.Fix;
            if(AtChapterPost(u) && FlatSq(u.pos,Route.depot)>=12.25f)return ActionKind.ChapterSupply;
            if(FlatSq(u.pos,Route.depot)<12.25f)
            {
                if(Site!=0 && !state.built)return ActionKind.Construct;
                if(u.hp<u.maxHp)return ActionKind.Treat;
                return ActionKind.Restock;
            }
            if(state.crates>0 && FlatSq(u.pos,Route.cache)<12.25f)return ActionKind.Retrieve;
            return ActionKind.None;
        }
        public string InteractionHint
        {
            get
            {
                switch(Context(Controlled,out var c))
                {
                    case ActionKind.ChapterSupply:return ChapterPostLabel+"を使う";
                    case ActionKind.ChapterStation:return Chapter.stage==0?ChapterJob.title:ChapterInstruction;
                    case ActionKind.PatchRoad:return "道路の応急補修";
                    case ActionKind.District:return RegisterAction(Controlled);
                    case ActionKind.CheckDuty:return DutyStage.goal==DutyGoal.FindShelter ? "待合室を調べる" : "巡回小屋を調べる";
                    case ActionKind.RepairBridge:return "連絡橋を直す";
                    case ActionKind.Alarm:return AlarmName+"を鳴らす";
                    case ActionKind.Optional:return OptionalStep.action==RequestAction.Freight?(state.requestCarrier>=0?"荷物を届ける":"要請の荷物を持つ"):"要請の設備を直す";
                    case ActionKind.Release:return "支援を中断";
                    case ActionKind.Lift:return "肩を支える";
                    case ActionKind.Resuscitate:return c.name+"を救護";
                    case ActionKind.Retrieve:return CargoLabel+"を持つ";
                    case ActionKind.Deliver:return CargoLabel+"を下ろす";
                    case ActionKind.Fix:return "設備を修理";
                    case ActionKind.Treat:return "手当てと補給";
                    case ActionKind.Construct:return "建設を進める";
                    case ActionKind.Restock:return "弾薬を補給";
                    default:return "";
                }
            }
        }
        public bool Interact()
        {
            var u=Controlled;
            var action=Context(u,out var c);if(action==ActionKind.None)return false;
            var a=Brain(u);
            switch(action)
            {
                case ActionKind.ChapterSupply:return TakeChapterSupply(u);
                case ActionKind.ChapterStation:return UseChapterStation(u,.3f);
                case ActionKind.PatchRoad:PatchFleetRoad();break;
                case ActionKind.District:var sector=NearbyDistrict(u);AdvanceDistrict(sector,DistrictAssignment(u.squad)==sector && DistrictTransport(u.squad),u);break;
                case ActionKind.CheckDuty:state.dutyFound=true;break;
                case ActionKind.RepairBridge:state.dutyBridge=true;PerformRepair(.25f);break;
                case ActionKind.Alarm:return ActivateAlarm();
                case ActionKind.Optional:PerformRequestWork(u,.25f);break;
                case ActionKind.Release:Unlink(u);break;
                case ActionKind.Lift:Link(u,c);break;
                case ActionKind.Resuscitate:u.medkits--;c.hp=36;c.active=true;c.wounded=true;break;
                case ActionKind.Retrieve:state.crates--;a.cargo=true;break;
                case ActionKind.Deliver:a.cargo=false;DeliverCrate();break;
                case ActionKind.Fix:
                    PerformRepair(.25f*WorkLight(u.pos));break;
                case ActionKind.Construct:
                    state.construction=Mathf.Min(1,state.construction+.25f);state.built=state.construction>=1;break;
                case ActionKind.Restock: case ActionKind.Treat:Supply(u,1);break;
            }
            u.escortId=a.escort;u.carryingCargo=a.cargo;
            return true;
        }
    }
}
