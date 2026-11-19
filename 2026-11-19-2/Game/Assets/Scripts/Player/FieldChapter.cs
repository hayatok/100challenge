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
        internal int QuestSquad
        {
            get
            {
                int fallback = -1;
                foreach (Unit soldier in roster)
                {
                    if (!soldier.active) continue;
                    if (soldier.squad == SelectedSquad) return SelectedSquad;
                    if (fallback < 0) fallback = soldier.squad;
                }
                return fallback;
            }
        }

        internal void SendQuestTeam(int branch)
        {
            int squad = QuestSquad;
            if (squad < 0 || (sim.ChapterChoice != branch && !sim.ChooseChapterOption(branch))) return;
            if (!sim.DispatchChapter(squad)) return;
            // A lone signal operator needs a partner from another squad if one is available.
            if (sim.ChapterNeedsSupport && roster.FindAll(u => u.active && u.squad == squad).Count == 1)
            {
                Unit partner = roster.Find(u => u.active && u.squad != squad);
                if (partner != null) sim.DispatchChapter(partner.squad, true);
            }
            mapCenter = sim.ChapterPoint();
            ShowOrderPin(mapCenter);
            sound.Signal("dispatch");
            sim.Save();
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
        }
    }
}
