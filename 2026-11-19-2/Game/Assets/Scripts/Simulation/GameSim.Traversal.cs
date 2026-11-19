using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        public float VaultLift(Unit u)
        {
            if (u==null || u.vaultDuration<=0) return 0;
            float fraction=Mathf.Clamp01(u.vaultTime/u.vaultDuration);
            return 4*fraction*(1-fraction)*u.vaultApex;
        }

        public bool TryVault(Vector3 direction)
        {
            var u=Controlled;
            if(u==null || Result!=SimResult.Active || u.reload>0 || u.dodgeTime>0 || u.vaultDuration>0 ||
                ChapterHandsBusy(u) || u.escortId>=0 || u.carryingCargo || u.stamina<.32f || u.hp<40 || Brain(u).stun>0) return false;
            if(!geometry.VaultEnd(u.pos,direction,out Vector3 end,out float obstacle)) return false;
            u.vaultFrom=u.pos;u.vaultTo=end;u.vaultTime=0;
            u.vaultDuration=Mathf.Clamp(.36f+Vector3.Distance(u.pos,end)*.075f,.38f,.69f);
            u.vaultApex=obstacle+.12f;u.stamina-=.30f;
            Brain(u).exhausted=.62f;
            Brain(u).hasPath=false;
            return true;
        }
        bool UpdateTraversal(Unit u,float dt)
        {
            if(u.vaultDuration<=0)return false;
            u.vaultTime=Mathf.Min(u.vaultTime+dt,u.vaultDuration);
            float t=u.vaultTime/u.vaultDuration;
            u.pos=Vector3.Lerp(u.vaultFrom,u.vaultTo,Mathf.SmoothStep(0,1,t));
            u.moving=true;
            if(t>=1){u.vaultTime=u.vaultDuration=0;u.pos=geometry.Clamp(u.vaultTo);}
            return true;
        }
    }
}
