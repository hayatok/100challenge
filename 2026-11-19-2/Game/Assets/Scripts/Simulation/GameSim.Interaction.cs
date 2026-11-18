using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        enum ActionKind { None, Release, Lift, Resuscitate, Retrieve, Deliver, Fix, Treat, Construct, Restock, Optional, Alarm, CheckDuty, RepairBridge }
        ActionKind Context(Unit u,out Unit nearby)
        {
            nearby=null;
            if(u==null || u.dodgeTime>0 || Result!=SimResult.Active)return ActionKind.None;
            var a=Brain(u);
            if(a.escort>=0)return ActionKind.Release;
            if(RequestInteraction(u))return ActionKind.Optional;
            if(a.requestCargo)return ActionKind.None;
            if(a.cargo)return FlatSq(u.pos,Route.depot)<12.25f?ActionKind.Deliver:ActionKind.None;
            float shortest=2.9f*2.9f;
            foreach(var c in state.units)
            {
                if(c==u || c.boarded || c.kind==UnitKind.Infected)continue;
                bool patient=IsSoldier(c)?!c.active && u.medkits>0:c.active && Brain(c).escort<0 && Brain(c).injured;
                if(!patient)continue;
                float d=FlatSq(c.pos,u.pos);
                if(d<shortest){shortest=d;nearby=c;}
            }
            if(nearby!=null)return IsSoldier(nearby)?ActionKind.Resuscitate:ActionKind.Lift;
            if(AtDutySearch(u))return ActionKind.CheckDuty;
            if(DutyAlternativeBridge && state.sectionRepair<1 && FlatSq(u.pos,ActiveWorks)<9)return ActionKind.RepairBridge;
            if(AtAlarm(u))return ActionKind.Alarm;
            if(((NeedsRepair && state.sectionRepair<1) || (Rail && !Repaired)) && FlatSq(u.pos,Route.works)<12.25f)return ActionKind.Fix;
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
                    PerformRepair(.25f);break;
                case ActionKind.Construct:
                    state.construction=Mathf.Min(1,state.construction+.25f);state.built=state.construction>=1;break;
                case ActionKind.Restock: case ActionKind.Treat:Supply(u,1);break;
            }
            u.escortId=a.escort;u.carryingCargo=a.cargo;
            return true;
        }
    }
}
