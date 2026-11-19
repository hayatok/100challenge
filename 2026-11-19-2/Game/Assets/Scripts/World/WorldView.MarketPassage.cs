using UnityEngine;

namespace Evac
{
    public sealed partial class WorldView
    {
        Transform marketGateSlab, marketShutter;
        AudioSource marketShutterAudio;
        int heardMarketImpact;

        void BuildMarketPassage(int mission)
        {
            marketGateSlab=null;
            marketShutter=null;
            marketShutterAudio=null;
            heardMarketImpact=0;
            if(mission!=0)return;

            Place("marketPassageFrame",MarketPassage.Gate);
            marketGateSlab=Place("marketGateSlab",MarketPassage.Gate).transform;
            marketShutter=Place("marketNeighborShutter",MarketPassage.Shutter).transform;
            Place("marketBoardingPoint",new Vector3(10.32f,0,-14.76f));
            var impactSound=new GameObject("Market shutter impact");
            impactSound.transform.SetParent(district.transform,false);
            marketShutterAudio=impactSound.AddComponent<AudioSource>();
            marketShutterAudio.clip=Resources.Load<AudioClip>("World/marketShutterImpact");
            marketShutterAudio.playOnAwake=false;
            marketShutterAudio.dopplerLevel=0;
            marketShutterAudio.spatialBlend=.82f;
            marketShutterAudio.rolloffMode=AudioRolloffMode.Linear;
            marketShutterAudio.minDistance=3f;
            marketShutterAudio.maxDistance=52f;
            marketShutterAudio.volume=.74f;
        }

        void DrawMarketPassage(GameSim field)
        {
            if(!marketGateSlab)return;

            // Match the physics clearance below the rising slab at every height.
            marketGateSlab.localPosition=MarketPassage.Gate+Vector3.up*(MarketPassage.GateHeight*field.MarketGateLift);
            float age=field.MarketImpactAge;
            var shutterCenter=MarketPassage.Shutter;
            float rebound=0, lean=0;
            if(age>=0 && age<.55f && field.MarketImpactCount>0)
            {
                float side=field.MarketImpactPoint.z>=shutterCenter.z?-1f:1f;
                rebound=side*.091f*Mathf.Exp(-age*7.2f)*Mathf.Sin(age*37f);
                lean=rebound*Mathf.Clamp(field.MarketImpactPoint.x-shutterCenter.x,-1.8f,1.8f)*24f;
            }
            marketShutter.localPosition=shutterCenter+Vector3.forward*rebound;
            marketShutter.localRotation=Quaternion.Euler(rebound*19f,lean,0);

            if(heardMarketImpact==field.MarketImpactCount)return;
            heardMarketImpact=field.MarketImpactCount;
            if(heardMarketImpact<=0 || age<0 || age>.32f || !marketShutterAudio.clip)return;
            var impact=field.MarketImpactPoint;
            marketShutterAudio.transform.localPosition=new Vector3(impact.x,1.1f,impact.z);
            marketShutterAudio.Play();
        }
    }
}
