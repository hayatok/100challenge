using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        public void ChooseResponse(int branch)
        {
            if(sim.ChooseChapterOption(branch))sound.Signal("radio");
        }
        public void AssignResponse(bool support)
        {
            if(!sim.DispatchChapter(SelectedSquad,support))return;
            mapCenter=sim.ChapterPoint(support);
            ShowOrderPin(mapCenter);
            sound.Signal("dispatch");
        }
        public void AssignPostSupply()
        {
            if(!sim.DispatchChapterSupply(SelectedSquad))return;
            mapCenter=sim.ChapterPostPosition;
            ShowOrderPin(mapCenter);
            sound.Signal("dispatch");
        }
        void ChapterMarker()
        {
            if(sim.IsDuty)return;
            if(sim.HasChapterPost && sim.ChapterPhase==2 && (sim.Controlled==null || Vector3.Distance(sim.Controlled.pos,sim.ChapterPostPosition)<17))
                WorldTag(sim.ChapterPostPosition+Vector3.up*1.8f,sim.ChapterPostLabel+"　"+sim.ChapterPostStock+"箱",new Color(.63f,.86f,.8f),false);
            if(sim.ChapterPhase!=1 && sim.ChapterPhase!=3)return;
            if(sim.ChapterChoice<0)return;
            bool helper=sim.ChapterAssigned(SelectedSquad)==1;
            var goal=sim.ChapterPoint(helper);
            string label=sim.ChapterInstruction;
            if(sim.Controlled!=null)
                label=sim.ChapterOptionTitle(sim.ChapterChoice)+"　"+Mathf.RoundToInt(Vector3.Distance(goal,sim.Controlled.pos))+"m";
            WorldTag(goal+Vector3.up*1.7f,label,new Color(1,.80f,.49f),true);
        }
    }
}
