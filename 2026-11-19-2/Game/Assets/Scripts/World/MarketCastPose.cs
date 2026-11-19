using UnityEngine;

namespace Evac
{
    public readonly struct MarketCastPose
    {
        readonly Vector3 channels;
        readonly bool active;

        MarketCastPose(Vector3 channels)
        {
            this.channels=channels;
            active=true;
        }

        internal static MarketCastPose Guide(bool waiting,float glance) =>
            new MarketCastPose(new Vector3(waiting?1:0,0,glance));

        internal static MarketCastPose Shopkeeper(bool waiting,bool crossing,float shoulder) =>
            new MarketCastPose(new Vector3(waiting?1:0,crossing?shoulder:0,shoulder));

        internal static MarketCastPose Infected(float anticipation,bool charging,float recovery) =>
            new MarketCastPose(new Vector3(anticipation,charging?1:0,recovery));

        internal struct Transition
        {
            public float pause, thread, release, glance;
            public bool held;
        }

        internal Vector4 Blend(int kind,float dt,ref Transition pose)
        {
            if(!active)
            {
                pose=default;
                return default;
            }
            // The pose lanes share the existing instancing slot with companion
            // anchors. The fourth channel identifies this independent payload.
            if(kind==1)
            {
                pose.thread=Mathf.MoveTowards(pose.thread,channels.y,dt*12);
                return new Vector4(channels.x,pose.thread,channels.z,2);
            }
            bool holding=channels.x>0;
            pose.pause=Mathf.MoveTowards(pose.pause,channels.x,dt*(holding?5.8f:8f));
            if(kind==0)
            {
                if(pose.held && !holding)pose.release=.53f;
                if(holding)
                {
                    pose.release=0;
                    if(!pose.held)pose.glance=channels.z;
                }
                float release=Mathf.Sin(Mathf.PI*Mathf.Clamp01(pose.release/.53f));
                pose.release=Mathf.Max(0,pose.release-dt);
                pose.held=holding;
                return new Vector4(pose.pause,release,pose.glance,2);
            }
            pose.thread=Mathf.MoveTowards(pose.thread,channels.y,dt*5.5f);
            return new Vector4(pose.pause,pose.thread,channels.z,2);
        }
    }
}
