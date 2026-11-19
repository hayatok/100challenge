#if UNITY_EDITOR
using System;
using System.Text;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        internal void VerifyWing(StringBuilder report)
        {
            for(int region=0;region<4;region++)
            {
                StartMission(region*2+1,Difficulty.Standard);
                Chapter.phase=2;state.sector=1;OpenSector(false);
                var unit=soldiers[0];
                foreach(var soldier in soldiers)soldier.pos=new Vector3(0,0,88);
                PrepareWing(.1f);
                Verify(WingActive && WingResidentId>=0 && !UseWing(2,0),"Wing is integrated and remote FPS use refused");
                var axis=new Vector3(-3.5f,0,120);
                Verify(!geometry.LineClear(axis-Vector3.right,axis+Vector3.right),"Closed rescue gate blocks line of sight");
                CheckWingTrip(0,0,0);
                int supplies=Stock;
                int plant=region==1 || region==3?1:0;
                CheckWingTrip(1,plant,1);
                Verify(WingRoomOpen(plant) && Save() && Load() && WingStationDone(1),"Gate and command survive resume");
                var gate=new Vector3(plant==0?-3.5f:3.5f,0,120);
                Verify(geometry.LineClear(gate-Vector3.right,gate+Vector3.right),"Powered doorway is physically open");
                CheckWingTrip(2,0,0);
                Verify(WingEscortId>=0 && (region!=0 || Wing.oxygenDelivered),"Resident pickup, with oxygen at clinic");
                CheckWingTrip(3,1,1);
                CheckWingTrip(5,0,0);
                Verify(WingComplete && !Wing.lost && !Find(WingResidentId).active,"Named resident reached chosen physical handoff");
                if(region==1)Verify(FlatSq(WingFreightPosition,WingPosition(5))<13,"Hand truck transferred across different squads");
                if(region==2)Verify(Wing.crowdArrived>0,"Public announcement evacuated passengers");
                if(region==3)Verify(Wing.shuttleArrived,"Garage recovery vehicle reached dispatcher");
                Verify(Stock>=supplies,"Dispatch returned freight");
                report.AppendLine(WingTitle+" alternate handoff, "+WingResidentName+", "+Elapsed.ToString("0.0")+"s");
            }
            StartMission(1,Difficulty.Story);Chapter.phase=2;state.sector=1;OpenSector(false);
            foreach(var s in soldiers)s.active=s==soldiers[0];
            var solo=soldiers[0];solo.pos=new Vector3(0,0,89);PrepareWing(.1f);
            Verify(Possess(solo.id) && !UseWing(0,1),"FPS requires real local approach");
            int initial=Stock;
            solo.pos=WingPosition(0)+Vector3.forward*2.4f;
            Verify(!AtWingStation(0) && WingDirectRequirement(0,1).Length>0 && !UseWing(0,1),"Out-of-reach desk explains approach and refuses use");
            solo.pos=WingPosition(0)+Vector3.forward*2.2f;
            Verify(AtWingStation(0) && WingDirectRequirement(0,1).Length==0,"Desk hint and action agree within reach");
            ManualWingTrip(0,1);
            Verify(Stock==initial-1 && WingAvailable(2,0),"Emergency pathway pays stock, bypasses power");
            ManualWingTrip(2,0);
            solo.pos=WingPosition(4);
            Verify(AtWingStation(4) && WingDirectRequirement(4,0).Contains(WingResidentName) && !UseWing(4,0),
                "Handoff names the missing resident and stays disabled at the correct desk");
            ManualWingTrip(4,0);
            Verify(WingComplete && !Find(WingResidentId).active,"Single FPS operator completed bypass and escort");
            StartMission(3,Difficulty.Story);Chapter.phase=2;state.sector=1;OpenSector(false);
            foreach(var s in soldiers)s.pos=new Vector3(0,0,89);
            PrepareWing(.1f);
            Verify(DispatchWing(0,0,0) && DispatchWing(2,1,0) && WingSquadStation(0)==0 && WingSquadStation(2)==1,
                "Two teams work independent rooms concurrently");
            Verify(Save() && Load() && WingSquadStation(2)==1,"Concurrent assignments survive suspend");
            for(int i=0;i<800 && (!WingDone(0) || !WingDone(1));i++)Tick(.1f);
            Verify(WingDone(0) && WingDone(1) && WingRoomOpen(0),"Both field crews reached different rooms");
            var replacement=soldiers[3];
            Verify(Possess(replacement.id),"Transfer to a third squad member");
            ManualWingTrip(2,0);
            CheckWingTrip(3,1,2);
            var patient=Find(WingResidentId);
            Damage(patient,1000,Vector3.zero);
            ManualWingTrip(5,0);
            Verify(Wing.lost && WingComplete && FlatSq(WingFreightPosition,WingPosition(5))<13,
                "Powered conveyor, lost resident, fallback paperwork and no artificial rescue credit");
            state.wingRevision=0;state.wing=null;Save();Load();
            Verify(!WingActive && !WingComplete,"Legacy mission without wing state remains exempt");
            campaign.wingReturns=new int[8];campaign.wingReturns[0]=1;
            StartMission(1,Difficulty.Story);
            var aide=Find(state.wingAide-1);
            Verify(aide!=null && aide.name==WingNames[0],"Named medical contact at next depot");
            var wounded=soldiers[0];wounded.pos=aide.pos;wounded.hp=42;
            Tick(.08f);
            Verify(wounded.hp>=72 && state.wingUses==1 && Save() && Load() && state.wingUses==1,
                "Depot contact physically attends wounded soldier and retains spent supplies");
            report.AppendLine("Manual single-soldier rescue, parallel crew, powered freight, resident loss, legacy state and returning depot medic confirmed.");
        }

        void CheckWingTrip(int station,int opt,int squad)
        {
            Verify(DispatchWing(squad,station,opt),"Dispatch "+station+" in "+WingTitle);
            for(int i=0;i<1200 && !WingStationDone(station) && Result==SimResult.Active;i++)Tick(.1f);
            Verify(WingStationDone(station),"Stalled "+WingTitle+" at "+station+" actor "+soldiers[squad*3].pos+" goal "+WingPosition(station)+" resident "+Find(WingResidentId).pos+" freight "+WingFreightPosition+" "+Result);
        }

        internal void ManualWingTrip(int station,int opt)
        {
            var u=Controlled;
            for(int i=0;i<1400 && !WingStationDone(station);i++){
                if(!UseWing(station,opt)){
                    var delta=geometry.Waypoint(u.pos,WingPosition(station))-u.pos;
                    if(delta.sqrMagnitude>.008f)Move(delta.normalized,0,Mathf.Min(.1f,delta.magnitude/5.3f));
                    Tick(.1f);
                }
            }
            Verify(WingStationDone(station),"Manual approach to room "+station);
        }
    }
}
#endif
