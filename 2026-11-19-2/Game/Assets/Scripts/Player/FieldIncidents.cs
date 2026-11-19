using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        int incidentSoundSerial;
        public string IncidentChoice(int sector,bool quick) => sim.EventChoiceName(sector,quick);
        void UpdateIncidents()
        {
            world.RenderIncident(sim);
            if(!sim.FieldEventLive(sim.Sector) || sim.FieldEventSerial==incidentSoundSerial)return;
            incidentSoundSerial=sim.FieldEventSerial;
            int sector=sim.EventSoundSector;
            if(!sim.FieldEventLive(sector))return;
            int kind=sim.FieldEventType(sector);
            string clip=kind==0?"incidentBell":kind==4?"incidentPump":kind==1 || kind==3?"incidentRoll":"relay";
            sound.At(clip,sim.EventObjectPosition(sector));
        }
    }
}
