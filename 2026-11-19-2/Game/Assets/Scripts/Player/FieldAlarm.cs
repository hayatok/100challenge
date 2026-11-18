using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        public string AlarmName => sim.AlarmName;
        public string AlarmHint => sim.AlarmHint;
        public Vector3 AlarmPoint => sim.AlarmPoint;
        public float AlarmRadius => sim.AlarmRadius;
        public int AlarmSerial => sim.AlarmSerial;
        public float AlarmActiveRemaining => sim.AlarmActiveRemaining;
        public float AlarmCooldownRemaining => sim.AlarmCooldownRemaining;
        public int AlarmActorId => sim.AlarmActorId;
        public int AlarmAttracted => sim.AlarmAttracted;
        public void DispatchAlarm()
        {
            if(Phase=="Playing" && sim.Controlled==null)sim.DispatchAlarm(SelectedSquad);
        }
        public void CancelAlarmDispatch()
        {
            if(Phase=="Playing")sim.CancelAlarmDispatch();
        }
    }
}
