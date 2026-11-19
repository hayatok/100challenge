using System;
using UnityEngine;

namespace Evac
{
    public enum Difficulty { Story, Standard, Hard }
    public enum UnitKind { Soldier, Civilian, Infected }
    public enum SquadOrder { Move, Guard, Guide, Engineer, Supply }
    public enum SimResult { Active, Victory, Defeat }
    public enum PowerCircuit { Drain, Lift, Barrier }
    public enum Facility { Clinic, Workshop }

    [Serializable]
    public class Unit
    {
        public int id, squad, ammo, reserve, medkits, variant, escortId = -1, shots;
        public string name;
        public UnitKind kind;
        public Vector3 pos, lastSeen, lastHitDirection;
        public float stamina=1f, dodgeTime;
        public float yaw,hp,maxHp,reload,windup,stagger,lastSeenAt = -1000;
        public bool distracted;
        public bool active = true,wounded,boarded,carryingCargo,moving,visible;
    }

    public sealed class MissionDef
    {
        public readonly int index,population,quota;
        public readonly string title,district,briefing;
        public readonly Vector3 entrance,assembly,gate,exit,depot,cache,works;
        public readonly bool rail;
        internal MissionDef(int id, RoutePlan r)
        {
            index=id; population=r.population; quota=r.quota; title=r.title; district=r.district; briefing=r.briefing;
            entrance=r.entrance; assembly=r.assembly; gate=r.gate; exit=r.exit; depot=r.depot; cache=r.cache; works=r.works;
            rail=r.task==RouteTask.Platform || r.task==RouteTask.Flood;
        }
    }
}
