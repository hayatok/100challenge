using System;
using UnityEngine;

namespace Evac
{
    [Serializable]
    internal sealed class SearchMemory
    {
        public int reports, inspected, found, returned, lost, supported, supplyCarrier;
        public int[] actors=new int[2], escorts=new int[2], dispatch=new int[3];
        public float[] work=new float[6];
        public bool forwardPost;
    }

    public partial class GameSim
    {
        SearchMemory checkedSearch;
        SearchMemory Search
        {
            get
            {
                var data=state.search ?? (state.search=new SearchMemory());
                if(!ReferenceEquals(data,checkedSearch)){
                    if(data.actors?.Length!=2)data.actors=new int[2];
                    if(data.escorts?.Length!=2)data.escorts=new int[2];
                    if(data.dispatch?.Length!=3)data.dispatch=new int[3];
                    if(data.work?.Length!=6)data.work=new float[6];
                    checkedSearch=data;
                }
                return data;
            }
        }
        SearchCase Missing => SearchCases.All[state.index];
        public bool HasSearch => IsReady && !IsDuty;
        public string SearchTitle => Missing.title;
        public string SearchCall => Missing.call;
        public string SearchReport(int i) => (Search.reports&(1<<i))!=0?Missing.notes[i]:"未聴取";
        public string SearchSupply(int i) => i==2 && Missing.EscortEquipment.Length>0 ? "現地の備品　"+Missing.EscortEquipment : "";
        public int SearchReportCount => ((Search.reports&1)!=0?1:0)+((Search.reports&2)!=0?1:0)+((Search.reports&4)!=0?1:0);
        public int SearchPosting(int squad) => HasSearch && squad>=0 && squad<3?Search.dispatch[squad]-1:-1;
        public int SearchResolved => Search.returned|Search.lost;
        public string SearchName(int i) => Missing.names[i];
        public string SearchPersonLine(int i)
        {
            int bit=1<<i;
            if((Search.returned&bit)!=0)return Missing.reunions[i];
            if((Search.lost&bit)!=0)return "搬送中に救助できなくなった。";
            if((Search.found&bit)==0)return "所在不明";
            if(NeedsSearchSupport(i)){
                var carrier=Find(Search.supplyCarrier-1);
                return carrier!=null && carrier.active ? Missing.EscortEquipment+"を持つ"+carrier.name+"か、隊員2人で迎えに来てください。":
                    Missing.desks[2]+"で"+Missing.EscortEquipment+"を確保するか、隊員2人で迎えに来てください。";
            }
            var escort=Find(Search.escorts[i]-1);
            return escort!=null && escort.active ? escort.name+"と救護班へ移動中" : "発見済み。迎えを待っている。";
        }
        public string SearchTaskName(int task)
        {
            if(task<0 || task>8)return "";
            if(task<3)return Missing.desks[task];
            if(task<6)return Missing.rooms[task-3];
            if(task<8)return Missing.names[task-6]+"の同行";
            return "前方救護所";
        }
        public bool SearchTaskOpen(int task)
        {
            if(!HasSearch || Result!=SimResult.Active || task<0 || task>8 || SearchResolved==3)return false;
            if(task==2 && NeedsSearchSupport(1) && Search.supplyCarrier!=0 && Find(Search.supplyCarrier-1)?.active!=true)return true;
            if(task<3)return (Search.reports&(1<<task))==0;
            if(task<6)return SearchReportCount>=2 && (Search.inspected&(1<<(task-3)))==0;
            if(task<8)return ((Search.found&~SearchResolved)&(1<<(task-6)))!=0;
            return SearchReportCount>0;
        }
        public Vector3 SearchPoint(int task)
        {
            if(task<0 || task>8)return ActiveDepot;
            if(task<6)return Ground(Missing.Point(task));
            if(task==8)return Ground(new Vector3(0,0,(Missing.arrangement%2==0?1:-1)*42));
            int who=task-6;
            var person=Find(Search.actors[who]-1);
            if(person==null)return ActiveDepot;
            var escort=Find(Search.escorts[who]-1);
            return escort!=null && escort.active && !NeedsSearchSupport(who) ? SearchHandoff(person) : person.pos;
        }
        Vector3 SearchHandoff(Unit person)
        {
            var depot=Ground(RoutePlan.All[state.index].depot+new Vector3(-2,0,2));
            if(!Search.forwardPost)return depot;
            var post=SearchPoint(8);
            return FlatSq(person.pos,post)<FlatSq(person.pos,depot)?post:depot;
        }
        public string SearchTaskState(int task)
        {
            if(task<3 && (Search.reports&(1<<task))!=0)return "聴取済み";
            if(task>=3 && task<6){
                int room=task-3;
                if((Search.inspected&(1<<room))!=0){
                    for(int i=0;i<2;i++)if(Missing.destinations[i]==room)return Missing.names[i];
                    return "無人";
                }
                if(SearchReportCount<2)return "報告が2件必要";
            }
            if(task==8 && Search.forwardPost)return "受入中";
            for(int i=0;i<3;i++)if(SearchPosting(i)==task)return new[]{"警備班","誘導班","整備班"}[i]+"が担当";
            return task<6 && Search.work[task]>0?"現地を確認中":"";
        }
        public bool CanSendSearch(int squad,int task)
        {
            if(!SearchTaskOpen(task) || squad<0 || squad>2)return false;
            foreach(var u in soldiers)if(u.active && u.squad==squad)return true;
            return false;
        }
        public bool SendSearch(int squad,int task)
        {
            if(!CanSendSearch(squad,task))return false;
            if(!Order(squad,SquadOrder.Move,SearchPoint(task)))return false;
            if(task==6 || task==7){
                var oldLead=Find(Search.escorts[task-6]-1);
                if(oldLead!=null && oldLead.squad!=squad)Search.escorts[task-6]=0;
            }
            for(int i=0;i<3;i++)if(Search.dispatch[i]==task+1)Search.dispatch[i]=0;
            Search.dispatch[squad]=task+1;
            SoundNotice(SearchTaskName(task)+"へ班を派遣");
            return true;
        }
        void CancelSearchDispatch(int squad)
        {
            if(IsDuty || state.search==null || squad<0 || squad>2)return;
            Search.dispatch[squad]=0;
            for(int i=0;i<2;i++){
                var u=Find(state.search.escorts[i]-1);
                if(u!=null && u.squad==squad && u!=Controlled)state.search.escorts[i]=0;
            }
        }
        bool TravelSearch(Unit u,float dt)
        {
            if(IsDuty || state.search==null)return false;
            int task=SearchPosting(u.squad);
            if(task<0)return false;
            if(!SearchTaskOpen(task)){Search.dispatch[u.squad]=0;return false;}
            var destination=SearchPoint(task);
            if(task==6 || task==7){
                Unit person=Find(Search.actors[task-6]-1);
                if(person!=null && Search.escorts[task-6]==u.id+1 && FlatSq(person.pos,u.pos)>12)return true;
            }
            Walk(u,destination,task>=6 && task<8?2.38f:3.55f,dt);
            return true;
        }
        bool IsSearchResident(Unit u) => !IsDuty && state.search!=null &&
            (state.search.actors[0]==u.id+1 || state.search.actors[1]==u.id+1);

        Unit FieldReader(int task,Vector3 point)
        {
            Unit nearest=null;float best=7.3f;
            foreach(var u in soldiers){
                if(!u.active || (u!=Controlled && SearchPosting(u.squad)!=task))continue;
                float d=FlatSq(u.pos,point);if(d<best){best=d;nearest=u;}
            }
            return nearest;
        }
        bool NeedsSearchSupport(int who) => who==1 && Missing.EscortEquipment.Length>0 && (Search.supported&2)==0;
        bool GiveSearchSupport(Unit person)
        {
            // A crew can accompany the resident in pairs. A lone player can collect the supply at the third source.
            int helpers=0;
            foreach(var u in soldiers)
                if(u.active && FlatSq(u.pos,person.pos)<11 && ++helpers==2)return true;
            var carrier=Find(Search.supplyCarrier-1);
            return carrier!=null && carrier.active && FlatSq(carrier.pos,person.pos)<11;
        }
        void StepSearch(float dt)
        {
            if(!HasSearch || SearchResolved==3)return;
            Search.forwardPost=SearchReportCount>0 && FieldReader(8,SearchPoint(8))!=null;
            for(int task=0;task<6;task++){
                if(!SearchTaskOpen(task))continue;
                Vector3 point=SearchPoint(task);var reader=FieldReader(task,point);
                if(reader==null)continue;
                Search.work[task]+=dt;
                if(Search.work[task]<(task<3?2.4f:3.6f))continue;
                for(int j=0;j<3;j++)if(Search.dispatch[j]==task+1)Search.dispatch[j]=0;
                if(task<3){
                    Search.reports|=1<<task;
                    if(task==2 && Missing.EscortEquipment.Length>0)Search.supplyCarrier=reader.id+1;
                    SoundNotice(task==2 && Missing.EscortEquipment.Length>0 ? reader.name+"が"+Missing.EscortEquipment+"を携行" :
                        Missing.desks[task]+"から報告。捜索帳を更新");
                    continue;
                }
                int room=task-3;Search.inspected|=1<<room;
                int who=Array.IndexOf(Missing.destinations,room);
                if(who<0){SoundNotice(Missing.rooms[room]+"には誰もいない");continue;}
                var person=Spawn(UnitKind.Civilian,point,Missing.names[who],-1);
                var a=Brain(person);a.auxiliary=true;a.discovered=true;
                Search.actors[who]=person.id+1;Search.escorts[who]=reader.id+1;Search.found|=1<<who;
                if(reader!=Controlled || SearchPosting(reader.squad)<0)Search.dispatch[reader.squad]=7+who;
                SoundNotice(person.name+"を発見。救護班まで同行");
            }
        }
        void FollowSearch(Unit person,float dt)
        {
            int who=Search.actors[0]==person.id+1?0:1,bit=1<<who;
            if(NeedsSearchSupport(who)){
                if(!GiveSearchSupport(person)){person.moving=false;return;}
                Search.supported|=1<<who;
                SoundNotice(person.name+"の同行準備が整った");
            }
            var escort=Find(Search.escorts[who]-1);
            if(escort==null || !escort.active || FlatSq(escort.pos,person.pos)>100){
                Search.escorts[who]=0;
                escort=FieldReader(who+6,person.pos);
                if(escort==null){person.moving=false;return;}
                Search.escorts[who]=escort.id+1;
            }
            if(FlatSq(person.pos,escort.pos)>1.2f)Walk(person,escort.pos,person.hp<52?2.08f:2.7f,dt);
            var handoff=SearchHandoff(person);
            if(FlatSq(person.pos,handoff)>7.5f || FlatSq(escort.pos,handoff)>11)return;
            Search.returned|=bit;Search.escorts[who]=0;person.active=false;person.moving=false;
            if(SearchPosting(escort.squad)==6+who)Search.dispatch[escort.squad]=0;
            state.medPacks++;state.stock++;
            SoundNotice(person.name+"が救護班に合流。"+Missing.reward+"を受領");
        }
        public int SearchReturnedCount => (Search.returned&1)+((Search.returned>>1)&1);
        public bool PreviousSearchReturn(int i) => campaign.searchReturns?.Length==8 && (campaign.searchReturns[state.index]&(1<<i))!=0;
        void RecordSearch()
        {
            if(campaign.searchReturns?.Length!=8)campaign.searchReturns=new int[8];
            if(state.search!=null)campaign.searchReturns[state.index]|=Search.returned;
        }
        void LoseSearchResident(Unit person)
        {
            int who=Search.actors[0]==person.id+1?0:1;
            Search.lost|=1<<who;Search.escorts[who]=0;
            SoundNotice(person.name+"の搬送を続けられません");
        }
    }
}
