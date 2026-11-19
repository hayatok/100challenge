using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        public bool HasChapterPost => !IsDuty && Chapter!=null && Chapter.postKind>0 && ChapterPhase>=2;
        public Vector3 ChapterPostPosition => HasChapterPost?Chapter.postSite:ActiveDepot;
        public int ChapterPostStock => HasChapterPost?Chapter.postStores:0;
        ChapterBenefit PostBenefit => (ChapterBenefit)(Chapter.postKind-1);
        public string ChapterPostLabel
        {
            get
            {
                if(!HasChapterPost)return "";
                switch(PostBenefit)
                {
                    case ChapterBenefit.Medicine:
                    case ChapterBenefit.Crew:return "前方救護所";
                    case ChapterBenefit.Tools:
                    case ChapterBenefit.Vehicle:return "現地整備所";
                    case ChapterBenefit.Passage:
                    case ChapterBenefit.Drain:return "避難案内所";
                    default:return "前方補給所";
                }
            }
        }

        Vector3 PlaceChapterPost(Vector3 destination)
        {
            var point=Ground(destination);
            if(FlatSq(point,ActiveDepot)>=25)return point;
            // Give the new service its own counter when the handoff was at the depot.
            var counter=Ground(ActiveDepot+Vector3.forward*5.5f);
            return FlatSq(counter,ActiveDepot)>=16 ? counter : Ground(ActiveDepot+Vector3.back*5.5f);
        }

        public bool DispatchChapterSupply(int squad)
        {
            if(!HasChapterPost || ChapterPostStock<=0 || squad<0 || squad>=3 || !soldiers.Exists(u=>u.active && u.squad==squad))return false;
            return Order(squad,SquadOrder.Supply,ChapterPostPosition);
        }

        bool AtChapterPost(Unit u) => HasChapterPost && ChapterPostStock>0 && FlatSq(u.pos,Chapter.postSite)<8;
        bool SupplyAtPost(int squad) => HasChapterPost && FlatSq(DestinationFor(squad),Chapter.postSite)<1;

        bool TakeChapterSupply(Unit u)
        {
            if(!AtChapterPost(u))return false;
            bool used=false;
            switch(PostBenefit)
            {
                case ChapterBenefit.Medicine:
                case ChapterBenefit.Crew:
                    if(u.hp<u.maxHp || u.medkits<2)
                    {
                        u.hp=Mathf.Min(u.maxHp,u.hp+40);u.wounded=u.hp<80;u.medkits=2;used=true;
                    }
                    break;
                case ChapterBenefit.Tools:
                case ChapterBenefit.Vehicle:
                    if(state.vehicle<100){state.vehicle=Mathf.Min(100,state.vehicle+20);used=true;}
                    if(u.reserve<90){u.reserve=Mathf.Min(90,u.reserve+24);used=true;}
                    break;
                case ChapterBenefit.Passage:
                case ChapterBenefit.Drain:
                    foreach(var c in state.units)
                    {
                        if(!IsCivilian(c) || !c.active || Brain(c).auxiliary || FlatSq(c.pos,Chapter.postSite)>22*22)continue;
                        var memory=Brain(c);
                        if(!memory.discovered){memory.discovered=true;used=true;}
                    }
                    if(u.medkits<2){u.medkits=2;used=true;}
                    break;
                default:
                    if(u.reserve<90){u.reserve=Mathf.Min(90,u.reserve+45);used=true;}
                    break;
            }
            if(!used)return false;
            Chapter.postStores--;SoundNotice(u.name+"が"+ChapterPostLabel+"を利用");return true;
        }
    }
}
