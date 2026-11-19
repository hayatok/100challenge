using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        public int CurrentDistrict => sim.Sector;
        public string FieldDistrict(int n) => sim.DistrictName(n);
        public string FieldTask(int n) => sim.DistrictWorkLabel(n);
        public string FieldPayoff(int n, bool transport) => sim.DistrictBrief(n, transport);
        public string FieldPost => sim.DistrictPostBrief;
        public int WaitingResidents(int n) => sim.DistrictResidents(n);
        public int FieldOutcome(int n) => sim.DistrictOutcome(n);
        public int SquadPosting(int squad) => sim.DistrictAssignment(squad);
        public bool CarriesManifest(int squad) => sim.DistrictTransport(squad);
        public bool CanPost(int squad, int n) => sim.CanDispatchDistrict(squad, n);
        public void InspectDistrict(int sector)
        {
            mapCenter = sim.DistrictPosition(sector);
            zoom = TouchUI ? 18 : 15;
        }
        public void SendDistrict(int sector, bool transport)
        {
            if (!sim.DispatchDistrict(SelectedSquad, sector, transport)) return;
            sound.Signal("dispatch");
            InspectDistrict(sector);
            ShowOrderPin(mapCenter);
        }
        public string FieldHeading(int n)
        {
            Vector3 p = sim.DistrictPosition(n);
            return p.z > 36 ? "北街区" : p.z < -36 ? "南街区" : "中央通り";
        }
        public bool HasPosting(int n)
        {
            for (int i = 0; i < 3; i++)
                if (SquadPosting(i) == n) return true;
            return false;
        }

        void DrawFieldContacts()
        {
            if (sim.RadioContact is Unit contact && (contact.kind != UnitKind.Infected || contact.visible))
                WorldTag(contact.pos + Vector3.up * 2.2f, contact.kind == UnitKind.Infected ? "警戒要請" : "救助要請", new Color(1,.69f,.42f), true);
            if (sim.IsDuty || sim.ChapterPhase==1 || sim.ChapterPhase==3) return;
            int assignment = sim.DistrictAssignment(SelectedSquad);
            int district = assignment >= 0 ? assignment : sim.Sector;
            if (sim.DistrictOutcome(district) == 1) return;
            Vector3 spot = sim.DistrictPosition(district);
            if (sim.Controlled != null && (assignment < 0 || (spot-sim.Controlled.pos).sqrMagnitude < 9)) return;
            string tag = sim.DistrictName(district) + "　" + sim.DistrictWorkLabel(district);
            if (sim.Controlled != null) tag += " " + Mathf.RoundToInt(Vector3.Distance(sim.Controlled.pos,spot)) + "m";
            WorldTag(spot + Vector3.up * 2.5f, tag, new Color(.52f,.85f,.87f), true);
        }
    }
}
