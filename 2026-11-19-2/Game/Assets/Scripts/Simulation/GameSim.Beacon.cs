using System;
using UnityEngine;

namespace Evac
{
    [Serializable] internal sealed class RescueBeacon
    {
        public int packs=2, carrier=-1, kind, serial;
        public Vector3 destination, position;
        public float until, nextCall;
    }

    public partial class GameSim
    {
        static readonly string[] BeaconNames={"誘引灯","誘導灯","作業灯"};
        RescueBeacon Lamp => state.beacon ??= new RescueBeacon();
        public string BeaconName(int squad) => BeaconNames[Mathf.Clamp(squad,0,2)];
        public Vector3 BeaconPoint => Lamp.position;
        public int BeaconType => Lamp.kind;
        public int BeaconSerial => Lamp.serial;
        public int BeaconPacks => Lamp.packs;
        public float BeaconSeconds => Mathf.Max(0,Lamp.until-Elapsed);
        public bool CanLight => IsReady && Result==SimResult.Active && (Lamp.packs>0 || Stock>0);
        bool HandsFree(Unit u) => u!=null && u.active && !ChapterHandsBusy(u) && u.escortId<0 && !u.carryingCargo && u.vaultDuration<=0 && u.dodgeTime<=0;
        public bool SetBeacon(int squad,Vector3 destination)
        {
            if(!CanLight || squad<0 || squad>=3)return false;
            destination=Ground(destination);
            if(Controlled!=null)
            {
                var u=Controlled;
                if(u.squad!=squad || !HandsFree(u) || u.reload>0 || FlatSq(u.pos,destination)>100 ||
                   !geometry.LineClear(u.pos+Vector3.up*1.3f,destination+Vector3.up*.3f))return false;
                ActivateBeacon(u,destination);
                return true;
            }
            Unit carrier=null;
            float near=float.PositiveInfinity;
            foreach(var u in soldiers)
            {
                if(u.squad!=squad || !HandsFree(u))continue;
                float distance=FlatSq(destination,u.pos);
                if(distance>=near)continue;
                carrier=u;near=distance;
            }
            if(carrier==null)return false;
            Lamp.carrier=carrier.id;
            Lamp.destination=destination;
            SoundNotice(carrier.name+"が"+BeaconName(squad)+"を設置しに向かいます");
            return true;
        }
        void ActivateBeacon(Unit u,Vector3 point)
        {
            if(Lamp.packs>0)Lamp.packs--;
            else state.stock--;
            Lamp.kind=u.squad;Lamp.position=point;Lamp.until=Elapsed+19;
            Lamp.carrier=-1;Lamp.nextCall=Elapsed;Lamp.serial++;
            SoundNotice(u.name+"が"+BeaconName(u.squad)+"を設置");
        }
        bool DeployingBeacon(Unit u,float dt)
        {
            if(u.id!=Lamp.carrier)return false;
            if(!HandsFree(u) || !CanLight){Lamp.carrier=-1;return false;}
            if(Walk(u,Lamp.destination,3.65f,dt))ActivateBeacon(u,Lamp.destination);
            return true;
        }
        void TickBeacon(float dt)
        {
            if(Lamp.carrier>=0 && (Find(Lamp.carrier)==null || !Find(Lamp.carrier).active))Lamp.carrier=-1;
            if(BeaconSeconds<=0 || Elapsed<Lamp.nextCall)return;
            Lamp.nextCall=Elapsed+.5f;
            if(Lamp.kind!=1)return;
            foreach(var c in state.units)
            {
                if(!c.active || !IsCivilian(c) || Brain(c).auxiliary || FlatSq(c.pos,BeaconPoint)>15*15)continue;
                if(geometry.LineClear(BeaconPoint+Vector3.up*.85f,c.pos+Vector3.up))Brain(c).discovered=true;
            }
        }
        bool BeaconLures(Unit enemy,Unit target) => BeaconSeconds>0 && Lamp.kind==0 && enemy.windup<=0 &&
            FlatSq(enemy.pos,BeaconPoint)<12*12 && (target==null || FlatSq(enemy.pos,target.pos)>3.5f*3.5f);
        float WorkLight(Vector3 p) => BeaconSeconds>0 && Lamp.kind==2 && FlatSq(p,BeaconPoint)<8*8 ? 1.8f : 1;
    }
}
