using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        int searchMarker=-1;
        int searchMission=-1;
        internal GameSim SearchSimulation => sim;
        public string SearchResultSummary => "市街捜索　救護班に合流 "+sim.SearchReturnedCount+"／2";
        internal void LocateSearchPoint(int task,bool send)
        {
            if(!sim.HasSearch || task<0 || task>8)return;
            if(send && !sim.SendSearch(SelectedSquad,task))return;
            searchMarker=task;searchMission=MissionIndex;
            if(sim.Controlled==null){mapCenter=sim.SearchPoint(task);zoom=TouchUI?17:14;}
            if(send)sound.Signal("dispatch");
        }
        void DrawSearchMarkers()
        {
            if(!sim.HasSearch)return;
            world.ShowSearchFurniture(sim);
            if(searchMission!=MissionIndex){searchMarker=-1;searchMission=MissionIndex;}
            int task=searchMarker;
            if(task<0 || !sim.SearchTaskOpen(task))task=sim.SearchPosting(SelectedSquad);
            if(task<0 || !sim.SearchTaskOpen(task)){
                if(sim.Controlled==null)return;
                float best=25;
                for(int i=0;i<8;i++){
                    if(!sim.SearchTaskOpen(i))continue;
                    float d=(sim.SearchPoint(i)-sim.Controlled.pos).sqrMagnitude;
                    if(d<best){task=i;best=d;}
                }
                if(task<0 || !sim.SearchTaskOpen(task))return;
            }
            var point=sim.SearchPoint(task);
            string label=task==6 || task==7?"救助　"+sim.SearchTaskName(task):sim.SearchTaskName(task);
            if(sim.Controlled!=null)label+="　"+Mathf.RoundToInt(Vector3.Distance(sim.Controlled.pos,point))+"m";
            WorldTag(point+Vector3.up*2.1f,label,new Color(.67f,.90f,.69f),true);
        }
    }
}
