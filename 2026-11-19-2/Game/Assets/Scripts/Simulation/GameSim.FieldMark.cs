using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        Unit radioContact;
        float radioExpiry;
        public Unit RadioContact => radioContact != null && radioContact.active && Find(radioContact.id) == radioContact && Elapsed < radioExpiry ? radioContact : null;

        public Unit SightContact(Vector3 eye, Vector3 forward)
        {
            Unit best = null;
            float bestAngle = .035f;
            foreach (var unit in state.units)
            {
                if (!unit.active || unit.boarded || unit.kind == UnitKind.Soldier) continue;
                Vector3 point = unit.pos + Vector3.up * 1.12f;
                Vector3 delta = point - eye;
                float depth = Vector3.Dot(delta, forward);
                if (depth < .5f || depth > 48) continue;
                float angle = Mathf.Max(0, (delta - depth * forward).magnitude - .46f) / depth;
                if (angle >= bestAngle || !geometry.LineClear(eye, point)) continue;
                best = unit;
                bestAngle = angle;
            }
            return best;
        }

        public bool RadioOrder(int squad, Unit contact)
        {
            if (Controlled == null || contact == null || !contact.active || Find(contact.id) != contact || squad < 0 || squad >= state.squads.Length) return false;
            bool danger = contact.kind == UnitKind.Infected;
            if (!danger && contact.kind != UnitKind.Civilian) return false;
            if (!geometry.LineClear(Controlled.pos + Vector3.up * 1.52f, contact.pos + Vector3.up * 1.12f)) return false;
            if (!Order(squad, danger ? SquadOrder.Guard : SquadOrder.Guide, contact.pos)) return false;
            radioContact = contact;
            radioExpiry = Elapsed + 18;
            if (danger) { contact.visible = true; contact.lastSeen = contact.pos; contact.lastSeenAt = Elapsed; }
            return true;
        }

        Unit PriorityContact(Unit responder, float radius)
        {
            var target = RadioContact;
            if (target == null || target.kind != UnitKind.Infected || FlatSq(responder.pos, target.pos) > radius * radius) return null;
            return geometry.LineClear(responder.pos + Vector3.up * 1.5f, target.pos + Vector3.up * 1.1f) ? target : null;
        }

        public bool SurfaceContact(Vector3 origin, Vector3 aim, out Vector3 point, out bool road)
        {
            float limit=45;
            float ground=aim.y<-.001f ? -origin.y/aim.y : float.PositiveInfinity;
            road=ground>=0 && ground<limit;
            if(road) limit=ground;
            point=origin+aim*limit;
            if(geometry.LineClear(origin,point)) return road;
            road=false;
            float left=0, right=limit;
            for(int i=0;i<10;i++)
            {
                float middle=(left+right)*.5f;
                if(geometry.LineClear(origin,origin+aim*middle)) left=middle;
                else right=middle;
            }
            point=origin+aim*left;
            return true;
        }
    }
}
