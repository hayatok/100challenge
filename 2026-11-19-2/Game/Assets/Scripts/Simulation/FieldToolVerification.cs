#if UNITY_EDITOR
using System;
using System.Text;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        internal void VerifyFieldTools(StringBuilder report)
        {
            void Require(bool value,string label){if(!value)throw new InvalidOperationException(label);}
            StartMission(1,Difficulty.Story);
            var guard=soldiers.Find(u=>u.squad==0);
            guard.pos=Ground(new Vector3(-.02f,0,69));
            Require(Possess(guard.id) && TryVault(Vector3.right),"Cannot cross the approach divider");
            Tick(.26f);
            Vector3 midway=guard.pos, landing=guard.vaultTo;
            Require(VaultLift(guard)>.55f && !Shoot(Vector3.forward),"Vault did not raise the view and occupy both hands");
            Require(Save() && Load(),"Vault suspend failed");
            guard=Controlled;
            Require((guard.pos-midway).sqrMagnitude<.001f && VaultLift(guard)>.55f,"Restored in-flight position changed");
            Release();
            Tick(guard.vaultDuration-guard.vaultTime+.008f);
            Require((guard.pos-landing).sqrMagnitude<.04f && guard.vaultDuration<=0,"AI did not finish the player's vault");
            Require(Possess(guard.id),"Cannot resume landed soldier");
            Vector3 emptyStreet=Ground(new Vector3(-2,0,62));
            guard.pos=emptyStreet;
            var contact=Spawn(UnitKind.Infected,emptyStreet+Vector3.forward*6,"接近者",-1);
            Vector3 eye=guard.pos+Vector3.up*1.52f;
            Vector3 ray=(contact.pos+Vector3.up*1.12f-eye).normalized;
            Require(SightContact(eye,ray)==contact && RadioOrder(0,contact) && RadioContact==contact,"Line of sight radio order failed");
            Require(SetBeacon(0,guard.pos+Vector3.right) && BeaconPacks==1 && BeaconSeconds>18,"FPS field lamp deployment failed");
            Require(Save() && Load() && BeaconPacks==1 && BeaconType==0 && BeaconSeconds>18,"Field lamp save lost remaining time");
            Release();
            var engineer=soldiers.Find(u=>u.squad==2);
            Require(SetBeacon(2,engineer.pos),"Cannot order a field lamp");
            for(int i=0;i<40 && BeaconType!=2;i++)Tick(.1f);
            Require(BeaconType==2 && BeaconPacks==0 && WorkLight(BeaconPoint)>1,"Dispatched engineer did not set the light");
            report.AppendLine("Vaulted real street furniture, saved in flight and landed under AI. Sight contact, a manual lamp, lamp restore and RTS engineer placement passed.");
        }
    }
}
#endif
