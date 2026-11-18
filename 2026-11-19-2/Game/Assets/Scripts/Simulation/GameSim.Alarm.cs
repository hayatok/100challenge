using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        static readonly string[] AlarmNames = {"防犯ベル","ヤードの警笛","駅の非常放送","入換ベル"};
        static readonly Vector3[] AlarmSites = {
            new Vector3(11,0,12),new Vector3(-11,0,13),new Vector3(-12,0,9),new Vector3(11,0,12)
        };
        static readonly float[] HearingRanges = {14,17,18,16};
        static readonly float[] SoundDurations = {7,6,9,7};
        int AlarmDistrict => state.index/2;
        public string AlarmName => AlarmNames[AlarmDistrict];
        Vector3 alarmSite;
        public Vector3 AlarmPoint => geometry==null ? AlarmSites[AlarmDistrict] : alarmSite;
        public float AlarmRadius => HearingRanges[AlarmDistrict];
        public float AlarmActiveRemaining => Mathf.Max(0,state.alarmUntil-Elapsed);
        public float AlarmCooldownRemaining => Mathf.Max(0,state.alarmReadyAt-Elapsed);
        public int AlarmActorId => state.alarmDispatch-1;
        public int AlarmSerial => state.alarmSerial;
        public int AlarmAttracted {get; private set;}

        public string AlarmHint
        {
            get
            {
                if(AlarmActiveRemaining>0)return AlarmName+" 作動中";
                if(AlarmCooldownRemaining>0)return "再使用まで "+Mathf.CeilToInt(AlarmCooldownRemaining)+"秒";
                var operatorUnit=Find(AlarmActorId);
                return operatorUnit!=null ? operatorUnit.name+"が装置へ移動中" : "現地で鳴らして感染者を引き寄せる";
            }
        }

        bool CanOperateAlarm(Unit u)
        {
            return IsReady && Result==SimResult.Active && AlarmCooldownRemaining<=0 &&
                u!=null && u.active && u.dodgeTime<=0 && Brain(u).escort<0 && !Brain(u).cargo;
        }
        bool AtAlarm(Unit u) => CanOperateAlarm(u) && FlatSq(u.pos,AlarmPoint)<=2.2f*2.2f &&
            geometry.LineClear(u.pos+Vector3.up*1.2f,AlarmPoint+Vector3.up*1.2f);

        public bool DispatchAlarm(int squad)
        {
            if(!IsReady || Result!=SimResult.Active || AlarmCooldownRemaining>0)return false;
            Unit selected=null;
            float closest=float.PositiveInfinity;
            Vector3 site=AlarmPoint;
            foreach(var u in soldiers)
            {
                if(u.squad!=squad || u==Controlled || !CanOperateAlarm(u))continue;
                float distance=FlatSq(u.pos,site);
                if(distance<closest){closest=distance;selected=u;}
            }
            if(selected==null || selected.id==AlarmActorId)return false;
            state.alarmDispatch=selected.id+1;
            SoundNotice(selected.name+"を"+AlarmName+"へ派遣");return true;
        }
        public bool CancelAlarmDispatch()
        {
            if(!IsReady || Result!=SimResult.Active || AlarmActorId<0)return false;
            state.alarmDispatch=0;SoundNotice("音源への派遣を取り消しました");return true;
        }
        public bool ActivateAlarm() => SoundAlarm(Controlled);
        bool SoundAlarm(Unit u)
        {
            if(!AtAlarm(u))return false;
            state.alarmSerial++;state.alarmDispatch=0;
            state.alarmUntil=Elapsed+SoundDurations[AlarmDistrict];
            state.alarmReadyAt=state.alarmUntil+20f;
            SoundNotice(u.name+"が"+AlarmName+"を作動");return true;
        }
        bool TravelToAlarm(Unit u, float dt)
        {
            if(u.id!=AlarmActorId)return false;
            if(!CanOperateAlarm(u)){state.alarmDispatch=0;return false;}
            Walk(u,AlarmPoint,3.6f,dt);
            if(AtAlarm(u))SoundAlarm(u);
            return true;
        }

        bool DivertedByAlarm(Unit enemy,ActorMemory memory,Unit target)
        {
            if(AlarmActiveRemaining<=0 || enemy.windup>0)return false;
            // Finish a committed attack and defend against someone already in reach.
            if(target!=null && target.active && FlatSq(target.pos,enemy.pos)<2.25f)return false;
            if(memory.alarmHeard!=AlarmSerial)
            {
                if(FlatSq(enemy.pos,AlarmPoint)>AlarmRadius*AlarmRadius)return false;
                memory.alarmHeard=AlarmSerial;
                memory.hasPath=false;
            }
            return true;
        }
        Vector3 AlarmApproach(Unit enemy)
        {
            // Different stopping positions leave physical space around the speaker.
            float angle=(enemy.id*137.5f)*Mathf.Deg2Rad;
            return AlarmPoint+new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*(.8f+enemy.id%3*.35f);
        }
    }
}
