using UnityEngine;

namespace Evac
{
    public enum RequestState { Unplayed, Offered, Accepted, Declined, Completed, Unfinished }
    internal enum RequestAction { Rescue, Freight, Repair, Pump }
    internal sealed class RequestStep
    {
        internal readonly RequestAction action;
        internal readonly string item;
        internal readonly Vector3 origin, delivery;
        internal RequestStep(RequestAction action, string item, float x, float z, float endX=0, float endZ=0)
        {
            this.action=action;this.item=item;
            origin=new Vector3(x,0,z);delivery=new Vector3(endX,0,endZ);
        }
    }

    internal sealed class RequestDef
    {
        internal readonly string title, brief;
        internal readonly RequestStep[] steps;
        RequestDef(string title,string brief,params RequestStep[] steps)
        { this.title=title;this.brief=brief;this.steps=steps; }
        static RequestStep Rescue(string name,float x,float z)=>new RequestStep(RequestAction.Rescue,name,x,z);
        static RequestStep Load(string item,float x,float z,float endX=0,float endZ=0)=>new RequestStep(RequestAction.Freight,item,x,z,endX,endZ);
        static RequestStep Fix(string item,float x,float z)=>new RequestStep(RequestAction.Repair,item,x,z);
        internal static readonly RequestDef[] All =
        {
            new RequestDef("診療所の看護師","裏道でけがをした看護師を補給所まで支えてください。救護車に戻れば隊員の手当てを手伝えます。",
                Rescue("看護師・宇野",-11,-1)),
            new RequestDef("薬局の予備薬","閉店した薬局に救急箱が二つ残っています。両方を補給所へ運ぶと、各班に救急品を配れます。",
                Load("薬局の救急箱",-11,-4),Load("分室の救急箱",10,8)),
            new RequestDef("保冷庫の血液製剤","倉庫の非常電源を直し、保冷箱を集積所へ。届いた製剤で負傷隊員を手当てできます。",
                Fix("保冷庫の電源",10,4),Load("製剤の保冷箱",9,7)),
            new RequestDef("夜勤班の携帯無線","屋上アンテナの配線と中継器を順に直してください。通信が戻れば補給車が弾薬を届けられます。",
                Fix("屋上アンテナの端子",-10,12),Fix("夜勤班の中継器",11,-3)),
            new RequestDef("駅務室の二人","戸締まりをしていた駅員二人が負傷しました。順に救護車へ届ければ、後続の乗客を案内できます。",
                Rescue("駅員・滝沢",-11,5),Rescue("駅員・小宮",7,18)),
            new RequestDef("地下道の補助ポンプ","排水回路に通電し、補助ポンプを直してください。稼働すれば地下道の水をさらに早く抜けます。",
                new RequestStep(RequestAction.Pump,"地下道の補助ポンプ",-10,9)),
            new RequestDef("河川敷の投光器","艇庫の蓄電池を堤防の投光器へ運び、端子を接続してください。灯りがつくと警備班が遠くを見渡せます。",
                Load("投光器の蓄電池",-11,8,8,6),Fix("堤防の投光器",8,6)),
            new RequestDef("整備主任の点検簿","整備主任を救護車へ運び、詰所の点検簿を回収してください。主任が記録を照合して輸送車を修理します。",
                Rescue("整備主任・橘",11,12),Load("車両の点検簿",-10,3))
        };
    }

    public partial class GameSim
    {
        RequestDef Optional => RequestDef.All[state.index];
        RequestStep OptionalStep => Optional.steps[Mathf.Clamp(state.requestStep,0,Optional.steps.Length-1)];
        public RequestState RequestStatus => (RequestState)state.requestState;
        public string RequestTitle => Optional.title;
        public string RequestDescription => Optional.brief;
        public string RequestTitleFor(int index) => index>=0 && index<8 ? RequestDef.All[index].title : "";
        public RequestState RequestOutcome(int index) => index>=0 && index<8 ? (RequestState)campaign.requests[index] : RequestState.Unplayed;
        public int CompletedRequests
        {
            get {int count=0;foreach(int outcome in campaign.requests)if(outcome==(int)RequestState.Completed)count++;return count;}
        }
        public bool HasRequestPoint => IsReady && Result==SimResult.Active && RequestStatus==RequestState.Accepted;
        public SquadOrder RequestOrder => OptionalStep.action==RequestAction.Rescue ? SquadOrder.Guide : SquadOrder.Engineer;
        public int RequestPropType => !HasRequestPoint || OptionalStep.action==RequestAction.Rescue ? 0 : OptionalStep.action==RequestAction.Freight ? 1 : 2;
        public string RequestPropLabel => OptionalStep.item;
        public Vector3 RequestPropPosition => state.requestCarrier>=0 && Find(state.requestCarrier) is Unit carrier ? carrier.pos : RequestPoint;
        public int RequestSquad => state.index==0 ? 0 : RequestOrder==SquadOrder.Guide?1:2;
        Vector3 RequestDelivery => Ground(OptionalStep.delivery==Vector3.zero ? Route.depot : OptionalStep.delivery);
        public Vector3 RequestPoint
        {
            get
            {
                if(!IsReady)return Vector3.zero;
                if(OptionalStep.action==RequestAction.Rescue && Find(state.requestActor) is Unit patient)
                    return Brain(patient).escort<0 ? patient.pos : RequestDelivery;
                return state.requestCarrier>=0 ? RequestDelivery : Ground(state.requestDropped ? state.requestDropPosition : OptionalStep.origin);
            }
        }
        public string RequestObjective
        {
            get
            {
                if(RequestStatus!=RequestState.Accepted)return RequestDescription;
                var step=OptionalStep;
                switch(step.action)
                {
                    case RequestAction.Rescue:
                        var patient=Find(state.requestActor);
                        return patient!=null && Brain(patient).escort>=0 ? step.item+"を補給所の救護車へ" : step.item+"に肩を貸す";
                    case RequestAction.Freight:
                        if(state.requestCarrier<0)return step.item+"を回収";
                        return step.item+(step.delivery==Vector3.zero?"を補給所へ":"を投光器へ");
                    case RequestAction.Pump:
                        if((PowerMask&1)==0)return "排水回路に通電";
                        break;
                }
                return step.item+"を修理　"+Mathf.RoundToInt(state.requestWork*100)+"%";
            }
        }

        public bool AcceptRequest()
        {
            if(!IsReady || IsDuty || Result!=SimResult.Active || RequestStatus!=RequestState.Offered)return false;
            state.requestState=(int)RequestState.Accepted;
            PrepareRequestActor();SoundNotice("追加要請を受諾　"+RequestTitle);Save();return true;
        }
        public bool DeclineRequest()
        {
            if(!IsReady || IsDuty || Result!=SimResult.Active || RequestStatus!=RequestState.Offered)return false;
            state.requestState=(int)RequestState.Declined;
            SoundNotice("追加要請を辞退　"+RequestTitle);Save();return true;
        }

        void PrepareRequestActor()
        {
            if(RequestStatus!=RequestState.Accepted || OptionalStep.action!=RequestAction.Rescue || state.requestActor>=0)return;
            var c=Spawn(UnitKind.Civilian,Ground(OptionalStep.origin),OptionalStep.item,-1);
            var a=Brain(c);a.auxiliary=true;a.injured=true;a.discovered=true;c.wounded=true;
            state.requestActor=c.id;
        }
        void CompleteRequestStep()
        {
            state.requestCarrier=-1;state.requestActor=-1;state.requestWork=0;state.requestDropped=false;state.requestStep++;
            if(state.requestStep<Optional.steps.Length)
            {
                SoundNotice("追加要請の次の現場　"+OptionalStep.item);
                return;
            }
            state.requestState=(int)RequestState.Completed;
            switch(state.index)
            {
                case 0:state.medPacks+=4;break;
                case 1:foreach(var s in soldiers)if(s.active)s.medkits++;state.medPacks+=4;break;
                case 2:foreach(var s in soldiers)if(s.active){s.hp=Mathf.Min(s.maxHp,s.hp+30);s.wounded=s.hp<80;}break;
                case 3:state.depotRounds+=120;break;
                case 4:state.liftCount+=4;break;
                case 7:state.vehicle=Mathf.Min(100,state.vehicle+45);state.stock+=4;break;
            }
            SoundNotice("追加要請を完了　"+RequestTitle);
        }
        void RequestPatient(Unit patient)
        {
            var a=Brain(patient);
            if(a.escort<0)return;
            var helper=Find(a.escort);
            if(helper==null || !helper.active){Unlink(patient);return;}
            patient.pos=geometry.Move(helper.pos,helper.pos+Quaternion.Euler(0,helper.yaw,0)*new Vector3(.48f,0,.58f));
            patient.yaw=helper.yaw;
            if(FlatSq(patient.pos,RequestDelivery)>5)return;
            Unlink(patient);patient.active=false;patient.moving=false;
            CompleteRequestStep();
        }

        bool RequestInteraction(Unit u)
        {
            if(!HasRequestPoint || OptionalStep.action==RequestAction.Rescue || FlatSq(u.pos,RequestPoint)>9)return false;
            var a=Brain(u);
            return a.escort<0 && (a.requestCargo || (!a.cargo && state.requestCarrier<0));
        }
        void PerformRequestWork(Unit u,float work)
        {
            var a=Brain(u);
            if(OptionalStep.action==RequestAction.Freight)
            {
                if(a.requestCargo)
                {
                    a.requestCargo=false;a.cargo=false;u.carryingCargo=false;CompleteRequestStep();
                }
                else if(state.requestCarrier<0)
                {
                    a.requestCargo=true;a.cargo=true;u.carryingCargo=true;state.requestDropped=false;state.requestCarrier=u.id;
                }
                return;
            }
            if(OptionalStep.action==RequestAction.Pump && (PowerMask&1)==0)return;
            state.requestWork=Mathf.Min(1,state.requestWork+work);
            if(state.requestWork>=1)CompleteRequestStep();
        }
        bool WorkRequest(Unit u,ActorMemory a,float dt)
        {
            if(!HasRequestPoint)return false;
            var other=Find(a.escort);
            if(other!=null && Brain(other).auxiliary)
            {
                Walk(u,RequestDelivery,2.7f,dt);return true;
            }
            if(a.requestCargo)
            {
                if(Walk(u,RequestDelivery,2.8f,dt))PerformRequestWork(u,dt);
                return true;
            }
            if(a.cargo || a.escort>=0 || !state.squads[u.squad].requestDuty || OrderFor(u.squad)!=RequestOrder)return false;
            if(OptionalStep.action==RequestAction.Rescue)
            {
                var patient=Find(state.requestActor);
                if(patient!=null && Brain(patient).escort<0 && Walk(u,patient.pos,3.6f,dt))Link(u,patient);
            }
            else if(state.requestCarrier<0 && Walk(u,RequestPoint,3.4f,dt))PerformRequestWork(u,dt*.10f);
            return true;
        }
        void RecordRequest()
        {
            if(RequestStatus==RequestState.Accepted)state.requestState=(int)RequestState.Unfinished;
            if(RequestStatus==RequestState.Offered)state.requestState=(int)RequestState.Declined;
            campaign.requests[state.index]=state.requestState;
        }
    }
}
