#if UNITY_EDITOR || EVAC_WEB_TEST || EVAC_INSPECTION
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        public int PrepareDutyCheckpointFailure()
        {
            if (!IsReady || !IsDuty || Result != SimResult.Active)
                return -1;

            Release();
            int dispatchedSector = -1;
            for (int step = 0; step < 3000 && Result == SimResult.Active; step++)
            {
                if (Sector > 0 && DutyStage.required != null)
                {
                    foreach (var person in state.units)
                    {
                        if (!person.active || !IsCivilian(person) || person.name != DutyStage.required)
                            continue;

                        var checkpoint = EvacStorage.Read<MissionMemory>(CheckpointSlot, Valid);
                        if (checkpoint == null || !checkpoint.duty || checkpoint.index != state.index ||
                            checkpoint.sector != Sector || checkpoint.result != (int)SimResult.Active)
                            return -1;

                        Damage(person, person.hp, Vector3.forward);
                        Tick(.04f);
                        return Result == SimResult.Defeat ? checkpoint.sector : -1;
                    }
                }

                if (dispatchedSector != Sector)
                {
                    dispatchedSector = Sector;
                    Order(0, SquadOrder.Guard, ActiveGate);
                    Order(1, SquadOrder.Guide, ActiveAssembly);
                    Order(2, SquadOrder.Engineer, EngineerDestination);
                }
                Tick(.1f);
            }
            return -1;
        }
    }
}
#endif
