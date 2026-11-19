using System;
using UnityEngine;

namespace Evac
{
    [Serializable]
    internal sealed class ChapterMemory
    {
        public int phase, pick, stage, resident, actor, runner, manual, earned, passageKits, toolKits;
        public int[] posting=new int[3];
        public bool dropped, portableSignal,arrivalWave;
        public string frontContact,retreatContact;
        public int liaison;
        public bool postDelivery,liaisonLost;
        public Vector3 drop,postSite;
        public int postKind,postStores;
        public float work;
    }

    public partial class GameSim
    {
        ChapterMemory Chapter => state.chapter;
        public int ChapterPhase => IsDuty ? 0 : Chapter?.phase ?? 0;
        public int ChapterChoice => (Chapter?.pick ?? 0)-1;
        bool ChapterField => ChapterPhase==1 || ChapterPhase==3;
        ChapterBeat CurrentBeat => ChapterPhase==1 ? ChapterCatalog.For(state.index).forward : ChapterCatalog.For(state.index).retreat;
        ChapterOption ChapterJob => ChapterField && ChapterChoice>=0 ? CurrentBeat.options[ChapterChoice] : null;
        public string ChapterTitle => ChapterField ? CurrentBeat.title : "";
        internal ChapterMemory QuestMemory => Chapter;
        internal float QuestWork => Chapter?.work ?? 0;
        internal string QuestDestination
        {
            get
            {
                if (Chapter.dropped) return "荷物まで";
                if (Chapter.stage == 0) return "現場まで";
                switch (ChapterJob.method)
                {
                    case ChapterMethod.Escort: return "同行先まで";
                    case ChapterMethod.Triage: return "搬送先まで";
                    case ChapterMethod.Survey: return "照合先まで";
                    case ChapterMethod.Repair: return "修理先まで";
                    default: return "届け先まで";
                }
            }
        }

        internal Vector3 QuestIncidentPosition => Ground(CurrentBeat.options[0].source);
        const float SignalReachSquared = 8;

        bool SignalStationFilled(bool support)
        {
            var job = ChapterJob;
            var point = Ground(support ? job.destination : job.source);
            foreach (Unit soldier in soldiers)
                if (soldier.active && FlatSq(soldier.pos, point) < SignalReachSquared) return true;
            return false;
        }

        internal bool QuestSignalPortable => ChapterNeedsSupport && Chapter.portableSignal;
        internal bool QuestSignalReady => ChapterNeedsSupport && SignalStationFilled(true) &&
            (QuestSignalPortable || SignalStationFilled(false));
        internal bool QuestSignalStationReached(Unit soldier) =>
            FlatSq(soldier.pos, QuestTarget(soldier)) < SignalReachSquared;
        internal bool CanTakeQuestDirectly => ChapterField && Controlled != null &&
            ChapterRunner == null && QuestAgent == null && Chapter.manual != Controlled.id + 1;

        internal bool TakeQuestDirectly()
        {
            if (ChapterJob == null || !CanTakeQuestDirectly) return false;
            if (ChapterNeedsSupport)
            {
                var partner = soldiers.Find(u => u.active && u != Controlled);
                if (partner != null) DispatchChapter(partner.squad, true);
            }
            Chapter.manual = Controlled.id + 1;
            Save();
            return true;
        }

        // A staffed signal station should not hide the crew still travelling to the opposite station.
        internal Unit QuestAgent
        {
            get
            {
                if (ChapterJob == null) return null;
                Unit carrier = ChapterRunner;
                if (carrier != null && carrier.active && ChapterAssigned(carrier.squad) >= 0) return carrier;
                Unit nearest = null;
                float best = float.PositiveInfinity;
                bool preferOpenStation = ChapterNeedsSupport && !QuestSignalPortable;
                bool sourceFilled = preferOpenStation && SignalStationFilled(false);
                bool endFilled = preferOpenStation && SignalStationFilled(true);
                bool bestStationFilled = true;
                foreach (Unit soldier in soldiers)
                {
                    int posting = ChapterAssigned(soldier.squad);
                    if (!soldier.active || posting < 0) continue;
                    bool support = ChapterSupport(soldier, posting);
                    bool stationFilled = support ? endFilled : sourceFilled;
                    float distance = FlatSq(soldier.pos, ChapterPoint(support));
                    if ((!stationFilled && bestStationFilled) || (stationFilled == bestStationFilled && distance < best))
                    {
                        nearest = soldier;
                        best = distance;
                        bestStationFilled = stationFilled;
                    }
                }
                return nearest;
            }
        }

        internal Vector3 QuestTarget(Unit soldier)
        {
            return ChapterPoint(soldier != null && ChapterSupport(soldier, ChapterAssigned(soldier.squad)));
        }

        bool ChapterSupport(Unit soldier, int posting)
        {
            if (Chapter.manual == soldier.id + 1) return false;
            if (posting == 1) return true;
            if (!ChapterNeedsSupport || Chapter.portableSignal || Array.IndexOf(Chapter.posting, 2) >= 0) return false;
            return soldiers.Find(member => member.active && member.squad == soldier.squad) != soldier;
        }

        public bool ChapterNeedsSupport => ChapterJob!=null && ChapterJob.method==ChapterMethod.Signal;
        public string ChapterIncident => ChapterField ? CurrentBeat.incident : "";
        static readonly string[] Benefits={"医療品3箱","備蓄3箱","協力者2人と医療品1箱","合流点の開放","荷役・修理の支援","車の耐久25と備蓄1箱","予備弾薬72発","排水を支援。地上では通路確保"};
        public string ChapterBenefitName => Chapter!=null && Chapter.earned>0 ? Benefits[Chapter.earned-1] : "";
        public string ChapterOptionTitle(int i) => ChapterField && i>=0 && i<2 ? CurrentBeat.options[i].title : "";
        public string ChapterOptionDetail(int i)
        {
            if(!ChapterField || i<0 || i>=2)return "";
            var job=CurrentBeat.options[i];return MethodText(job.method)+"　"+Benefits[(int)job.benefit];
        }
        static string MethodText(ChapterMethod method)
        {
            switch(method)
            {
                case ChapterMethod.Survey:return "二地点の記録を照合";
                case ChapterMethod.Transfer:return "現物を受け取り、届ける";
                case ChapterMethod.Triage:return "負傷者を支えて搬送";
                case ChapterMethod.Escort:return "住民の歩幅に合わせて同行";
                case ChapterMethod.Signal:return "両端から同時に合図";
                default:return "部品を持って故障箇所を修理";
            }
        }

        public string ChapterInstruction
        {
            get
            {
                var job=ChapterJob;
                if(job==null)return ChapterField ? "対応を二つから選択" : "";
                if(Chapter.dropped)return "現地に残った荷物を受け取る";
                if(job.method==ChapterMethod.Signal)return Chapter.portableSignal?"携帯中継器をもう一方の端へ":"二か所に隊員を配置。単独なら携帯中継器を運ぶ";
                if(Chapter.stage==0)return MethodText(job.method);
                switch(job.method)
                {
                    case ChapterMethod.Survey:return "もう一方の記録と照合";
                    case ChapterMethod.Escort:return "住民と合流先まで歩く";
                    case ChapterMethod.Triage:return "負傷者を受け入れ先へ運ぶ";
                    case ChapterMethod.Repair:return "現場で取り付け　"+Mathf.RoundToInt(Chapter.work*100)+"%";
                    default:return "受け入れ先に届ける";
                }
            }
        }

        static bool ValidChapter(ChapterMemory chapter)
        {
            if(chapter==null || chapter.phase==0)return true;
            if(chapter.phase<1 || chapter.phase>4 || chapter.pick<0 || chapter.pick>2 ||
                chapter.stage<0 || chapter.stage>1 || chapter.earned<0 || chapter.earned>Benefits.Length ||
                chapter.postKind<0 || chapter.postKind>Benefits.Length || chapter.postStores<0 ||
                chapter.posting==null || chapter.posting.Length!=3)return false;
            foreach(var role in chapter.posting)if(role<0 || role>2)return false;
            return true;
        }

        void ReturnChapterCarrierToAI(Unit pawn)
        {
            if(pawn!=null && ChapterField && ChapterAssigned(pawn.squad)<0 &&
                (ChapterRunner==pawn || ChapterNeedsSupport && Chapter.manual==pawn.id+1))
                Chapter.posting[pawn.squad]=1;
        }

        void InitChapter(bool restoring)
        {
            if(IsDuty)return;
            if(Chapter==null || Chapter.phase<1 || Chapter.phase>4)
                state.chapter=new ChapterMemory {
                    phase=restoring?(Result==SimResult.Victory?4:2):1
                };
            if(Chapter.posting?.Length!=3)Chapter.posting=new int[3];
        }

        public int ChapterAssigned(int squad) => ChapterField && squad>=0 && squad<3 ? Chapter.posting[squad]-1 : -1;
        Unit ChapterResident => Chapter==null ? null : Find(Chapter.resident-1);
        Unit ChapterRunner => Chapter==null ? null : Find(Chapter.runner-1);
        bool IsChapterLiaison(Unit u) => Chapter!=null && Chapter.liaison==u.id+1;
        public string ChapterLiaisonLine
        {
            get
            {
                var liaison=Chapter!=null?Find(Chapter.liaison-1):null;
                if(liaison==null)return "";
                return liaison.name+(Chapter.liaisonLost?"は行動不能":Chapter.postDelivery?"が前方拠点へ補給済み":HasChapterPost?"が前方拠点へ補給中":"が集積所で待機");
            }
        }

        public string ReturnedChapterContact(int operation,bool retreat)
        {
            if(campaign.chapterContacts?.Length!=16 || operation<0 || operation>=8)return "";
            return campaign.chapterContacts[operation*2+(retreat?1:0)] ?? "";
        }

        void BringForwardContact()
        {
            if(IsDuty || state.index==0 || !campaign.complete[state.index-1])return;
            string name=ReturnedChapterContact(state.index-1,true);
            if(name.Length==0)name=ReturnedChapterContact(state.index-1,false);
            if(name.Length==0)return;
            var liaison=Spawn(UnitKind.Civilian,ActiveDepot+Vector3.left*1.4f,name,-1);
            Brain(liaison).auxiliary=true;Brain(liaison).discovered=true;
            Chapter.liaison=liaison.id+1;
        }

        void StepChapterLiaison(Unit u,float dt)
        {
            if(!HasChapterPost || Chapter.postDelivery)return;
            if(!Walk(u,ChapterPostPosition,2.6f,dt))return;
            Chapter.postStores++;Chapter.postDelivery=true;
            SoundNotice(u.name+"が前方拠点に補給箱を届けました");
        }

        bool IsChapterResident(Unit u) => ChapterField && Chapter.resident==u.id+1;
        bool ChapterHandsBusy(Unit u)
        {
            var job=ChapterJob;
            return job!=null && Chapter.runner==u.id+1 && (job.method==ChapterMethod.Triage || job.method==ChapterMethod.Transfer ||
                (job.method==ChapterMethod.Repair && Chapter.stage==1));
        }

        public bool ChooseChapterOption(int i)
        {
            if(!IsReady || Result!=SimResult.Active || !ChapterField || i<0 || i>=2 || ChapterChoice==i)return false;
            var previous=ChapterResident;if(previous!=null){previous.active=false;previous.moving=false;}
            Chapter.pick=i+1;Chapter.stage=0;Chapter.runner=0;Chapter.manual=0;Chapter.resident=0;Chapter.work=0;Chapter.dropped=false;Chapter.portableSignal=false;
            Array.Clear(Chapter.posting,0,3);
            var job=ChapterJob;
            if(job.method==ChapterMethod.Triage || job.method==ChapterMethod.Escort)
            {
                var person=Find(Chapter.actor-1);
                string name=job.residentName ?? (job.method==ChapterMethod.Triage?"搬送を待つ負傷者":"同行する連絡員");
                if(person==null){person=Spawn(UnitKind.Civilian,job.source,name,-1);Chapter.actor=person.id+1;}
                else{person.name=name;person.pos=Ground(job.source);person.active=true;person.boarded=false;}
                Brain(person).hasPath=false;
                Brain(person).auxiliary=true;Brain(person).discovered=true;
                person.wounded=job.method==ChapterMethod.Triage;Chapter.resident=person.id+1;
            }
            SoundNotice(job.title);Save();return true;
        }

        public Vector3 ChapterPoint(bool support=false)
        {
            var job=ChapterJob;
            if(job==null)return ActiveDepot;
            if(support || Chapter.portableSignal)return Ground(job.destination);
            if(Chapter.dropped)return Chapter.drop;
            if(Chapter.stage==0 && ChapterResident!=null)return ChapterResident.pos;
            return Ground(Chapter.stage==0 ? job.source : job.destination);
        }

        void CancelChapterDispatch(int squad)
        {
            if(!ChapterField || squad<0 || squad>=3)return;
            Chapter.posting[squad]=0;
            var runner=ChapterRunner;
            if(runner!=null && runner.squad==squad && runner!=Controlled)DropChapterLoad(runner);
        }

        void DropChapterLoad(Unit u)
        {
            if(Chapter==null || Chapter.runner!=u.id+1)return;
            Chapter.runner=0;
            Chapter.dropped=true;Chapter.drop=ChapterResident!=null?ChapterResident.pos:u.pos;
        }

        public bool DispatchChapter(int squad,bool support=false)
        {
            var job=ChapterJob;
            if(!IsReady || Result!=SimResult.Active || job==null || squad<0 || squad>=3 ||
                (support && job.method!=ChapterMethod.Signal) || !soldiers.Exists(u=>u.active && u.squad==squad))return false;
            if(Wing!=null)Wing.jobs[squad]=0;
            ClearWaypoints(squad);
            CancelSearchDispatch(squad);state.squads[squad].districtTask=0;
            Chapter.manual=0;
            Chapter.posting[squad]=support?2:1;
            SoundNotice(job.title+"へ派遣");return true;
        }

        bool AtChapter(Unit u)
        {
            var job=ChapterJob;if(job==null)return false;
            if(job.method==ChapterMethod.Signal && FlatSq(u.pos,Ground(job.destination))<SignalReachSquared)return true;
            return FlatSq(u.pos,ChapterPoint())<8;
        }

        int ActiveChapterCrew()
        {
            int count=0;foreach(var u in soldiers)if(u.active)count++;return count;
        }

        bool UseChapterStation(Unit u,float amount)
        {
            var job=ChapterJob;if(job==null)return false;
            if(job.method==ChapterMethod.Signal)
            {
                bool nearSource=FlatSq(u.pos,Ground(job.source))<SignalReachSquared;
                if(nearSource && ActiveChapterCrew()==1){Chapter.portableSignal=true;return true;}
                bool nearEnd=FlatSq(u.pos,Ground(job.destination))<SignalReachSquared;
                if(!nearEnd && !nearSource)return false;
                Vector3 opposite=Ground(nearEnd?job.source:job.destination);
                foreach(var other in soldiers)
                    if(other!=u && other.active && FlatSq(other.pos,opposite)<SignalReachSquared){FinishChapterBeat();return true;}
                if(nearEnd && Chapter.portableSignal){FinishChapterBeat();return true;}
                return true;
            }
            if(!AtChapter(u))return false;
            if(Chapter.dropped){Chapter.dropped=false;Chapter.runner=u.id+1;return true;}
            if(Chapter.stage==0)
            {
                Chapter.stage=1;
                if(job.method!=ChapterMethod.Survey)Chapter.runner=u.id+1;
                return true;
            }
            if(Chapter.runner!=0 && Chapter.runner!=u.id+1)return false;
            if(ChapterResident!=null && FlatSq(ChapterResident.pos,ChapterPoint())>14)return false;
            if(job.method==ChapterMethod.Repair)
            {
                Chapter.work=Mathf.Min(1,Chapter.work+amount);
                if(Chapter.work<1)return true;
            }
            FinishChapterBeat();return true;
        }

        bool ChapterDuty(Unit u,float dt)
        {
            var job=ChapterJob;int posting=ChapterAssigned(u.squad);
            if(job==null || posting<0)return false;
            bool support=ChapterSupport(u,posting);
            if(Chapter.runner!=0 && ChapterRunner!=u && job.method!=ChapterMethod.Signal)
                return false;
            if(!ChapterHandsBusy(u))
            {
                var a=Brain(u);
                if(a.fireDelay<=0 && u.reload<=0)
                {
                    if(u.ammo<=0)StartReload(u);
                    else
                    {
                        var threat=NearestThreat(u.pos,11);
                        if(threat!=null)HitShot(u,threat,(threat.pos-u.pos).normalized,true);
                    }
                }
            }
            var person=ChapterResident;
            if(person!=null && Chapter.stage==1 && job.method==ChapterMethod.Escort && FlatSq(person.pos,u.pos)>10)return true;
            var goal=ChapterPoint(support);
            if(FlatSq(u.pos,goal)>3)Walk(u,goal,ChapterHandsBusy(u)?2.7f:3.6f,dt);
            else UseChapterStation(u,dt*.23f);
            return true;
        }

        void MoveChapterResident(Unit person,float dt)
        {
            var escort=ChapterRunner;
            if(escort==null || !escort.active)return;
            if(ChapterJob.method==ChapterMethod.Triage)
            {
                person.pos=geometry.Clamp(escort.pos+Quaternion.Euler(0,escort.yaw,0)*new Vector3(.4f,0,.4f));
                person.moving=escort.moving;person.yaw=escort.yaw;
            }
            else if(FlatSq(person.pos,escort.pos)>1.4f)Walk(person,escort.pos,2.8f,dt);
        }

        void ChapterRescueFailed()
        {
            state.result=(int)SimResult.Defeat;state.controlled=-1;
            SoundNotice("現場の連絡員を救助できませんでした。局面の記録から再開できます");Save();
        }

        void ApplyChapterBenefit(ChapterBenefit benefit)
        {
            switch(benefit)
            {
                case ChapterBenefit.Medicine:state.medPacks+=3;break;
                case ChapterBenefit.Freight:state.stock+=3;break;
                case ChapterBenefit.Crew:state.volunteers+=2;state.medPacks++;break;
                case ChapterBenefit.Passage:Chapter.passageKits++;break;
                case ChapterBenefit.Tools:Chapter.toolKits++;break;
                case ChapterBenefit.Vehicle:state.vehicle=Mathf.Min(100,state.vehicle+25);state.stock++;break;
                case ChapterBenefit.Reserve:state.depotRounds+=72;break;
                case ChapterBenefit.Drain:if(!Rail)Chapter.passageKits++;state.water=Mathf.Max(0,state.water-.45f);state.liftClock=0;state.liftCount=Mathf.Max(9,state.liftCount);break;
            }
            UseChapterSupplies();
        }

        void UseChapterSupplies()
        {
            if(IsDuty || Chapter==null || ChapterPhase==3)return;
            if(Chapter.passageKits>0 && NeedsScreen && !state.screened){state.screened=true;Chapter.passageKits--;}
            if(Chapter.passageKits>0 && SectorData.work==FieldWork.Gather)
            {
                foreach(var c in state.units)
                    if(c.active && IsCivilian(c) && Brain(c).sector==Sector && !Brain(c).auxiliary && !Brain(c).fieldShelter)Brain(c).discovered=true;
                Chapter.passageKits--;
            }
            if(Chapter.toolKits>0)
            {
                if(NeedsRepair && state.sectionRepair<1){PerformRepair(.55f);Chapter.toolKits--;}
                else if(NeedsCargo && SectorTrips<RequiredTrips){state.delivered++;Chapter.toolKits--;}
            }
        }

        void FinishChapterBeat()
        {
            var job=ChapterJob;
            int next=ChapterPhase==1?2:4;
            var resident=ChapterResident;
            if(resident!=null)
            {
                if(next==2)Chapter.frontContact=resident.name;else Chapter.retreatContact=resident.name;
                resident.active=false;resident.moving=false;
            }
            Chapter.earned=(int)job.benefit+1;Chapter.resident=0;Chapter.runner=0;Chapter.manual=0;Chapter.pick=0;Chapter.phase=next;
            Array.Clear(Chapter.posting,0,3);
            ApplyChapterBenefit(job.benefit);
            if(next==2)
            {
                Chapter.postSite=PlaceChapterPost(job.destination);Chapter.postKind=(int)job.benefit+1;Chapter.postStores=3;
                state.deadline=Elapsed+(state.index==0?360:720)*(Level==Difficulty.Hard?.8f:1);
                state.waveIn=Mathf.Max(state.waveIn,12);
                if(state.index>0)Chapter.arrivalWave=true;
            }
            SoundNotice(job.title+"を完了。"+Benefits[(int)job.benefit]);
            EvacStorage.Write(CheckpointSlot,state);Save();
        }

        void BeginChapterRetreat()
        {
            if(ChapterPhase!=2 || Sector!=SectorCount-1 || !IsSectorCleared() || state.exitClock<1 ||
                (FleetEnabled && (FleetDecisionPending || FleetDelivered<Mission.quota)))return;
            Chapter.phase=3;Chapter.pick=0;Chapter.runner=0;Chapter.manual=0;Chapter.resident=0;Chapter.dropped=false;
            state.deadline=Elapsed+(Level==Difficulty.Hard?270:360);
            SoundNotice(ChapterTitle+"　"+ChapterIncident);
            EvacStorage.Write(CheckpointSlot,state);Save();
        }
    }
}
