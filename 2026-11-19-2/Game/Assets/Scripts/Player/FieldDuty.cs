namespace Evac
{
    public sealed partial class GameSession
    {
        public bool IsDuty => sim.IsDuty;
        public int DutyIndex => sim.DutyIndex;
        public string CurrentDutyTitle => sim.IsDuty ? GameSim.DutyName(sim.DutyIndex) : "";
        public string CurrentDutyEnding => sim.DutyEnding;
        public bool HasDutySave => sim.HasDutySave;
        public string DutyName(int district) => GameSim.DutyName(district);
        public string DutyBrief(int district) => GameSim.DutyBrief(district);
        public bool DutyCompleted(int district) => sim.DutyCompleted(district);
        public void StartDuty(int district)
        {
            sim.StartDuty(district,(Difficulty)difficulty);
            EnterField();
        }
        public void ContinueDuty()
        {
            if(sim.LoadDuty())EnterField();
        }
        public void RetryDuty()
        {
            if(!sim.IsDuty)return;
            sim.Retry();EnterField();
        }
    }
}
