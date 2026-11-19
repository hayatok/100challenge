using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        RoutePlan Route => activePlan ?? BasePlan;
        bool Rail => Route.task == RouteTask.Platform || Route.task == RouteTask.Flood;
        bool NeedsCargo => !(DutyAlternativeBridge && state.dutyBridge) &&
            !(IsDuty && DutyStage.goal==DutyGoal.DispatchMedicine && Site==1) &&
            (SectorData.work==FieldWork.Haul || SectorData.work==FieldWork.HaulAndRepair);
        bool NeedsRepair => (DutyAlternativeBridge && state.dutyBridge) || SectorData.work==FieldWork.Repair || SectorData.work==FieldWork.HaulAndRepair || SectorData.work==FieldWork.Generator;
        int RequiredTrips => IsDuty ? (DutyStage.goal==DutyGoal.TransferGoods?2:1) : Route.task == RouteTask.Convoy ? 3 : 2;
        int SectorTrips => state.delivered-state.sectionDelivered;
        public bool PassageOpen => (!NeedsCargo || SectorTrips >= RequiredTrips) &&
            (!NeedsRepair || state.sectionRepair>=1) && (!NeedsScreen || state.screened) && (!Rail || (state.water < .73f && (state.powerMask & 2) != 0));

        void UpdateInfrastructure(float dt)
        {
            if ((!NeedsCargo || SectorTrips >= RequiredTrips) && (!NeedsRepair || state.sectionRepair>=1))
                state.exitClock = Mathf.MoveTowards(state.exitClock, 1, dt / 6f);
            if (Rail)
            {
                state.water = Mathf.Clamp01(state.water + (((state.powerMask & 1) != 0) ? (state.index==5 && RequestStatus==RequestState.Completed ? -.047f : -.026f) : .012f) * dt);
                state.liftClock -= dt;
                if (state.liftClock <= 0 && PassageOpen)
                {
                    state.liftCount = state.index==4 && RequestStatus==RequestState.Completed ? 9 : 6;
                    state.liftClock = 4.5f;
                }
            }
        }

        void DeliverCrate()
        {
            state.stock+=3;state.delivered++;state.depotRounds+=24;state.medPacks++;
        }

        void Engineer(Unit u, ActorMemory a, float dt)
        {
            if (a.cargo)
            {
                if (Walk(u, Route.depot, 2.8f, dt))
                {
                    a.cargo = false;
                    DeliverCrate();
                    SoundNotice(CargoLabel+"が集積所に到着");
                }
                return;
            }
            if (NeedsCargo && SectorTrips < RequiredTrips)
            {
                if (state.crates > 0 && Walk(u, Route.cache, 3.5f, dt)) { state.crates--; a.cargo = true; }
                return;
            }
            if ((NeedsRepair && state.sectionRepair<1) || (Rail && !state.repaired))
            {
                if (!Walk(u, Route.works, 3.3f, dt)) return;
                PerformRepair(dt * (state.built && state.site == 2 ? .075f : .036f));
                return;
            }
            if (state.site != 0 && !state.built)
            {
                if (Walk(u, Route.depot, 3.2f, dt))
                {
                    state.construction += dt * .09f;
                    if (state.construction >= 1)
                    {
                        state.built = true; state.construction = 1;
                        SoundNotice(state.site == 1 ? "救護所を開設" : "修理場が稼働");
                    }
                }
                return;
            }
            if (state.crates > 0 && Walk(u, Route.cache, 3.3f, dt)) { state.crates--; a.cargo = true; }
            else if (state.crates == 0) Walk(u, Route.depot, 3.3f, dt);
        }

        void Guide(Unit u, ActorMemory a, float dt)
        {
            if (a.escort >= 0)
            {
                var patient = Find(a.escort);
                if (patient == null || !Active(patient)) { a.escort = -1; return; }
                var memory = Brain(patient);
                Vector3 next = memory.route < 1 ? memory.personalGate : Door(patient);
                if (Walk(u, next, 2.7f, dt) && memory.route == 0 && AllowCrossing(memory))
                    memory.route = 1;
                return;
            }
            Unit match = null;
            float closest = float.MaxValue;
            foreach (Unit c in state.units)
            {
                if (!IsCivilian(c) || !Active(c)) continue;
                var m = Brain(c);
                if (m.auxiliary || m.escort >= 0 || (m.discovered && !m.injured)) continue;
                if (!m.discovered && !SectorDispatched(u.squad)) continue;
                if (!m.discovered && FlatSq(state.squads[u.squad].destination,c.pos)>144 && FlatSq(u.pos,c.pos)>49) continue;
                float d = FlatSq(u.pos,c.pos);
                if (d < closest) { closest = d; match = c; }
            }
            if (match == null)
            {
                Walk(u, Route.gate, 3.4f, dt);
                return;
            }
            Walk(u, match.pos, 3.6f, dt);
            if (closest < 6.25f)
            {
                var m = Brain(match);
                m.discovered = true;
                if (m.injured) Link(u, match);
            }
        }

        void Link(Unit u, Unit civilian)
        {
            u.escortId=civilian.id;civilian.escortId=u.id;
            Brain(u).escort = civilian.id;
            Brain(civilian).escort = u.id;
            Brain(civilian).discovered = true;
        }

        void Unlink(Unit u)
        {
            var a = Brain(u);
            if (a.escort >= 0)
            {
                var other = Find(a.escort);
                if (other != null) {Brain(other).escort = -1;other.escortId=-1;}
                a.escort = -1;u.escortId=-1;
            }
        }

        void PerformRepair(float amount)
        {
            state.sectionRepair=Mathf.Min(1,state.sectionRepair+amount);
            if(Rail) {state.repair=Mathf.Min(1,state.repair+amount);state.repaired=state.repair>=1;}
            else {state.repair=state.sectionRepair;state.repaired=state.sectionRepair>=1;}
            if(state.sectionRepair>=1)SoundNotice("設備が復旧、通行可能");
        }
        bool AllowCrossing(ActorMemory m)
        {
            if(m.sector<Sector)return true;
            if (!PassageOpen) return false;
            if (!Rail) return true;
            if (state.liftCount <= 0) return false;
            state.liftCount--;
            return true;
        }

        Vector3 Door(Unit c)
        {
            // Adjacent doors serve independent queues while sharing the same vehicle.
            return Route.exit + new Vector3(0,0,(c.id % 3 - 1) * 1.8f);
        }

        void Civilian(Unit c, ActorMemory m, float dt)
        {
            if (m.escort >= 0)
            {
                var helper = Find(m.escort);
                if (helper == null || !Active(helper)) { Unlink(c); return; }
                c.pos = geometry.Move(helper.pos,helper.pos + Quaternion.Euler(0, helper.yaw, 0) * new Vector3(.48f,0,.58f));
                c.yaw = helper.yaw;
                if (m.route == 0 && FlatSq(c.pos, m.personalGate) < 9f && AllowCrossing(m)) m.route = 1;
                if (m.route == 1 && state.exitClock >= 1 && FlatSq(c.pos, Door(c)) < 6f) Board(c);
                return;
            }
            if (!m.discovered)
            {
                foreach (Unit soldier in soldiers)
                {
                    if (Active(soldier) && FlatSq(c.pos,soldier.pos) < 49f &&
                        geometry.LineClear(soldier.pos+Vector3.up*1.5f,c.pos+Vector3.up))
                    { m.discovered = true; break; }
                }
            }
            if (!m.discovered || m.injured) return;
            var next = m.route == 0 ? m.personalGate : Door(c);
            if (!Walk(c, next, 2.25f + (c.id % 6) * .1f, dt)) return;
            if (m.route == 0)
            {
                if (AllowCrossing(m)) m.route++;
            }
            else if (state.exitClock >= 1) Board(c);
        }
    }
}
