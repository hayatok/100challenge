using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed class FieldAudio : MonoBehaviour
    {
        readonly Dictionary<string,AudioClip> clips=new Dictionary<string,AudioClip>();
        AudioSource radio,voice,weather,pulse,fieldAlarm;
        int alarmDistrict=-1;
        readonly AudioSource[] locations=new AudioSource[12];
        int next;
        float threatTimer, signalTime;
        void Awake()
        {
            foreach(var clip in Resources.LoadAll<AudioClip>("Sound")) clips[clip.name]=clip;
            radio=Source(false); weather=Loop("rain"); pulse=Loop("pulse");
            voice=Source(false);
            fieldAlarm=Source(true);
            fieldAlarm.loop=true;
            fieldAlarm.volume=.8f;
            fieldAlarm.maxDistance=65;
            for(int i=0;i<locations.Length;i++) locations[i]=Source(true);
        }
        AudioSource Source(bool positioned)
        {
            var item=new GameObject(positioned?"Field sound":"Receiver");
            item.transform.SetParent(transform,false);
            var s=item.AddComponent<AudioSource>();s.playOnAwake=false;
            s.spatialBlend=positioned?.85f:0;s.minDistance=3f;s.maxDistance=48;
            s.rolloffMode=AudioRolloffMode.Linear;s.dopplerLevel=0;return s;
        }
        AudioSource Loop(string name)
        {
            var s=Source(false);
            if(clips.TryGetValue(name,out var c)){s.clip=c;s.volume=0;s.loop=true;s.Play();}
            return s;
        }
        public void SetPlay(bool on)
        {
            if(weather)weather.volume=on?.32f:.12f;
            if(pulse)pulse.volume=on?.09f:0;
            if(!on && fieldAlarm && fieldAlarm.isPlaying)fieldAlarm.Stop();
        }
        public void SetFieldAlarm(Vector3 point,int district,bool on)
        {
            if(!on){if(fieldAlarm.isPlaying)fieldAlarm.Stop(); return;}
            if(alarmDistrict!=district)
            {
                alarmDistrict=district;
                clips.TryGetValue("field_alarm_"+district,out var clip);
                fieldAlarm.clip=clip;
            }
            fieldAlarm.transform.position=point+Vector3.up*1.7f;
            if(fieldAlarm.clip && !fieldAlarm.isPlaying)fieldAlarm.Play();
        }
        public void Signal(string key)
        {
            if(radio && clips.TryGetValue(key,out var c)) radio.PlayOneShot(c,key=="board"?.38f:.72f);
        }
        public float Say(string key,bool urgent=false)
        {
            if((voice.isPlaying&&!urgent)||!clips.TryGetValue(key,out var clip))return 0;
            voice.Stop();voice.clip=clip;voice.volume=.83f;voice.Play();
            return clip.length;
        }
        public void At(string key,Vector3 pos)
        {
            if(!clips.TryGetValue(key,out var clip))return;
            var source=locations[next++%locations.Length];source.transform.position=pos;source.clip=clip;source.volume=.45f;
            source.pitch=.92f+(next%5)*.043f;source.Play();
        }
        public void Tick(float dt,GameSim sim,Vector3 ear,bool direct)
        {
            threatTimer-=dt;signalTime-=dt;
            if(threatTimer>0)return;threatTimer=.35f;
            float nearest=999;Unit near=null;
            foreach(var u in sim.Units)
            {
                if(!u.active||u.kind!=UnitKind.Infected)continue;
                float d=(u.pos-ear).sqrMagnitude;
                if(d<nearest){nearest=d;near=u;}
            }
            float stress=(1-Mathf.Clamp01(Mathf.Sqrt(nearest)/(direct?33:84)))*.44f+.08f;
            pulse.volume=Mathf.Lerp(pulse.volume,voice.isPlaying?stress*.35f:stress,.3f);
            if(near!=null && signalTime<=0 && nearest<(direct?20*20:65*65))
            {At("infected",near.pos);signalTime=3.7f+(near.id%6)*.42f;}
        }
    }
}
