using System;
using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    [Serializable]
    internal class ActorMemory
    {
        public int alarmHeard;
        public int sector; public Vector3 personalGate, waypoint, pathGoal; public bool hasPath;
        public int id, escort = -1, target = -1, route, variant;
        public bool injured, cargo, discovered, preparingCharge, auxiliary, requestCargo;
        public Vector3 dodgeVelocity, chargeHeading;
        public float exhausted,chargeTime;
        public float fireDelay, attackClock, stun, supplyClock, aidClock, lostTime;
        public Vector3 impulse, lastSeen;
    }

    [Serializable]
    internal class SquadMemory
    {
        public int order, sector;
        public Vector3 destination;
        public bool assigned, requestDuty;
    }

    [Serializable]
    internal class ReturnedSoldier
    {
        public int operation;
        public string name;
        public float hp;
        public bool returned;
    }

    [Serializable]
    internal class CampaignLog
    {
        public int version = 1, unlocked, bestTotal;
        public int[] best = new int[8], latest = new int[8], facilities = new int[8], freight = new int[8], injured = new int[8], returned = new int[8];
        public bool[] complete = new bool[8];
        public int[] requests = new int[8];
        public List<ReturnedSoldier> roster = new List<ReturnedSoldier>();
        public bool Valid() => version == 1 && unlocked >= 0 && unlocked < 8 && best?.Length == 8 &&
            latest?.Length == 8 && facilities?.Length == 8 && freight?.Length == 8 && injured?.Length == 8 && returned?.Length == 8 && complete?.Length == 8;
    }

    [Serializable]
    internal class MissionMemory
    {
        public int requestState=(int)RequestState.Offered,requestStep,requestActor=-1,requestCarrier=-1;
        public float requestWork;public bool departureAnnounced,requestDropped;
        public Vector3 requestDropPosition;
        public bool duty, dutyBridge, dutyFound, dutyFailed;
        public int dutyAlarmBaseline;
        public string dutyFailure;
        public int alarmDispatch,alarmSerial;
        public float alarmUntil,alarmReadyAt;
        public int volunteers, depotRounds, medPacks;
        public int sector, sectionBoarded, sectionDelivered, sectionAssists; public float sectionRepair,security; public bool screened;
        public int version = 2, index, difficulty, result, controlled = -1, nextId, boarded, losses, kills, crates, delivered;
        public int stock, waveCount, powerMask = 3, site, cargoTrips, repairCount;
        public float clock, waveIn, deadline, water, repair, construction, vehicle = 100, liftClock, exitClock, autosave, anchorX, anchorZ;
        public int liftCount;
        public bool repaired, built, checkpoint, exited;
        public uint random;
        public List<Unit> units = new List<Unit>();
        public List<ActorMemory> actors = new List<ActorMemory>();
        public SquadMemory[] squads = new SquadMemory[3];

        public float Draw()
        {
            random ^= random << 13; random ^= random >> 17; random ^= random << 5;
            return (random & 0xffffff) / 16777216f;
        }
    }
}
