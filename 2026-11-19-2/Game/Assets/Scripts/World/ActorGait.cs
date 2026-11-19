using UnityEngine;

namespace Evac
{
    internal static partial class ActorGait
    {
        internal const float HipHeight=.87f, KneeHeight=.49f, AnkleHeight=.125f, AnkleX=.109f;
        const float Thigh=HipHeight-KneeHeight, Shin=KneeHeight-AnkleHeight;
        const float Turn=2*Mathf.PI;

        internal struct Foot
        {
            internal Vector3 anchor;
            internal float weight;
            internal bool planted;
        }

        internal static float Smooth(float low,float high,float value)
        {
            float t=Mathf.Clamp01((value-low)/(high-low));
            return t*t*(3-2*t);
        }

        static Vector4 Sample(int offset,int key,float t)
        {
            Vector4 start=Keys[offset+key], end=Keys[offset+key+1];
            Vector4 before=Keys[offset+(key+11)%12], after=Keys[offset+(key+2)%12];
            float t2=t*t,t3=t2*t;
            Vector4 v=(2*t3-3*t2+1)*start+(t3-2*t2+t)*(end-before)*.5f+
                      (-2*t3+3*t2)*end+(t3-t2)*(after-start)*.5f;
            for(int i=0;i<4;i++)v[i]=Mathf.Clamp(v[i],Mathf.Min(start[i],end[i]),Mathf.Max(start[i],end[i]));
            return v;
        }

        static Vector4 Gait(int channel,int key,float blend,float run,float limp)
        {
            return Vector4.Lerp(Vector4.Lerp(Sample(channel*13,key,blend),
                Sample((3+channel)*13,key,blend),run),Sample((6+channel)*13,key,blend),limp);
        }

        internal static bool Solve(float phase,float stride,float limp,int side,Vector3 root,
                                   Quaternion yaw,Vector3 scale,float dt,ref Foot foot,out Vector4 angles)
        {
            float cycle=Mathf.Repeat(phase,Turn)*12/Turn;
            int key=Mathf.Min((int)cycle,11);
            float blend=cycle-key;
            float run=Smooth(.58f,.96f,stride), move=Smooth(.01f,.38f,stride);
            Vector4 limb=Gait(side,key,blend,run,limp)*move;
            Vector4 body=Gait(2,key,blend,run,limp)*move;
            float x=side==0?-AnkleX:AnkleX;
            float hipKnee=limb.x+limb.y;
            float footPitch=hipKnee+limb.z;
            float y=HipHeight-Thigh*Mathf.Cos(limb.x)-Shin*Mathf.Cos(hipKnee)+body.x;
            float z=-Thigh*Mathf.Sin(limb.x)-Shin*Mathf.Sin(hipKnee);
            float sway=body.y*Smooth(.12f,.86f,y);
            Vector3 sample=new Vector3(x+sway,y,z);
            Vector3 world=root+yaw*Vector3.Scale(sample,scale);
            float footFrame=Mathf.Repeat(cycle+side*6,12);
            float last= Mathf.Lerp(Mathf.Lerp(StanceEnd[side],StanceEnd[side+2],run),StanceEnd[side+4],limp);
            bool contact=footFrame<=last+.04f;
            if(contact && !foot.planted)
            {
                foot.anchor=world;
                foot.weight=0;
            }
            foot.planted=contact;
            foot.weight=Mathf.MoveTowards(foot.weight,contact?1:0,dt*(contact?23:12));
            Vector3 offset=foot.anchor-world;
            offset.y=0;
            float weight=foot.weight*(1-Smooth(.23f,.41f,offset.magnitude));
            if(weight<.002f || offset.sqrMagnitude<.000001f)
            {
                angles=default;
                return false;
            }
            Vector3 delta=Quaternion.Inverse(yaw)*(offset*weight);
            float targetX=delta.x/scale.x;
            float targetZ=z+delta.z/scale.z;
            float rise=HipHeight+body.x-y;
            float down=Mathf.Sqrt(rise*rise+targetX*targetX);
            float d=Mathf.Clamp(Mathf.Sqrt(down*down+targetZ*targetZ),
                Mathf.Abs(Thigh-Shin)+.001f,Thigh+Shin-.0001f);
            float hip=-Mathf.Atan2(targetZ,down)-
                Mathf.Acos(Mathf.Clamp((d*d+Thigh*Thigh-Shin*Shin)/(2*d*Thigh),-1,1));
            float knee=Mathf.PI-Mathf.Acos(Mathf.Clamp((Thigh*Thigh+Shin*Shin-d*d)/(2*Thigh*Shin),-1,1));
            angles=new Vector4(hip,knee,footPitch,Mathf.Atan2(targetX,rise));
            return true;
        }
    }
}
