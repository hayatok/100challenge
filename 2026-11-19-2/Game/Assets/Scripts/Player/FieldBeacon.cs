using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        bool choosingBeacon;
        int seenBeacon;
        float beaconGlint;
        public string LampName => sim.BeaconName(sim.Controlled!=null ? sim.Controlled.squad : SelectedSquad);
        public bool PickingLamp => choosingBeacon;
        public bool LampAvailable => sim.CanLight;
        public string LampCost => sim.BeaconPacks>0 ? "残り"+sim.BeaconPacks+"本" : "資材1";
        public void UseLamp()
        {
            if(Phase!="Playing" || !sim.CanLight)return;
            if(sim.Controlled==null){choosingBeacon=!choosingBeacon;return;}
            var u=sim.Controlled;
            var forward=Quaternion.Euler(0,u.yaw,0)*Vector3.forward;
            Vector3 dest=u.pos+forward*(pitch>27 ? 1.6f : 5.5f);
            if(!sim.SetBeacon(u.squad,dest))sim.SetBeacon(u.squad,u.pos);
        }
        void TargetLamp(Vector3 p)
        {
            if(sim.SetBeacon(SelectedSquad,p))
            {
                choosingBeacon=false;
                ShowOrderPin(p);
                sound.Signal("dispatch");
            }
        }
        void UpdateLamp(float dt)
        {
            float seconds=sim.BeaconSeconds;
            Color hue=sim.BeaconType==0?new Color(1,.42f,.15f):sim.BeaconType==1?new Color(.33f,.92f,.69f):new Color(.83f,.86f,1f);
            world.SetSignalLight(sim.BeaconPoint,hue,seconds);
            if(seenBeacon!=sim.BeaconSerial)
            {
                seenBeacon=sim.BeaconSerial;
                sound.At("relay",sim.BeaconPoint);
                beaconGlint=0;
            }
            if(seconds<=0)return;
            beaconGlint-=dt;
            if(beaconGlint<=0)
            {
                fx.Beacon(sim.BeaconPoint,hue,seenBeacon,ReducedMotion);
                beaconGlint=ReducedMotion?.32f:.105f;
            }
        }
        void BeaconTag()
        {
            if(sim.BeaconSeconds>0 && sim.Controlled==null)
                WorldTag(sim.BeaconPoint+Vector3.up*1.55f,sim.BeaconName(sim.BeaconType)+"　"+Mathf.CeilToInt(sim.BeaconSeconds)+"秒",new Color(.81f,.91f,.67f),true);
        }
    }
}
