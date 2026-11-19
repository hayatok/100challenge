using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        public RequestState RequestStatus => sim.RequestStatus;
        public string RequestTitle => sim.RequestTitle;
        public string RequestDescription => sim.RequestDescription;
        public string RequestObjective => sim.RequestObjective;
        public string RequestSquadName => SquadName(sim.RequestSquad);
        public int CompletedRequests => sim.CompletedRequests;
        public string RequestRecord(int mission) => sim.RequestTitleFor(mission)+"　"+RequestLabel(sim.RequestOutcome(mission));
        public static string RequestLabel(RequestState state)
        {
            switch(state)
            {
                case RequestState.Completed: return "対応完了";
                case RequestState.Accepted: return "対応中";
                case RequestState.Declined: return "見送り";
                case RequestState.Unfinished: return "未完了";
                case RequestState.Offered: return "未応答";
                default: return "記録なし";
            }
        }
        public void AcceptRequest()
        {
            if(sim.AcceptRequest())sound.Signal("radio");
        }
        public void DeclineRequest()
        {
            if(sim.DeclineRequest())sound.Signal("dial");
        }
        public void DispatchRequest()
        {
            if(!sim.HasRequestPoint)return;
            SelectSquad(sim.RequestSquad);
            SelectOrder((int)sim.RequestOrder);
            IssueOrder(sim.RequestPoint);
            mapCenter=sim.RequestPoint;
        }
    }
}
