#if UNITY_WEBGL && EVAC_WEB_TEST && !UNITY_EDITOR
using System.Runtime.InteropServices;
using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        [DllImport("__Internal")] static extern void InspectState(string phase,string mode,int ammo,float x,float z,float yaw,int fingers);
        [DllImport("__Internal")] static extern void InspectBearing(string destination,int offscreen,int frame);
        void InspectFieldBearing(string destination,bool offscreen)
        {
            if (Event.current.type==EventType.Repaint)
                InspectBearing(destination,offscreen ? 1 : 0,Time.frameCount);
        }
        [DllImport("__Internal")] static extern int InspectDutyFailure(int sector,int expected,int unchanged);
        [DllImport("__Internal")] static extern int InspectFloodColumns();
        [DllImport("__Internal")] static extern void InspectQuest(int phase,int choice,int agent,float x,float z,int wing,
            int stage,float nextX,float nextZ,int manual);
        [DllImport("__Internal")] static extern void InspectMarket(int leader,int pawn,float towardX,float towardZ,float lift,int boarded,int finished,int meeting,int waiting,float clock);
        bool preparedFlood,preparedFailure;
        int expectedSector=-1;
        string normalRecord, normalCheckpoint;
        void ReportControls()
        {
            if(!preparedFlood && Phase=="Title" && InspectFloodColumns()!=0)
            {
                preparedFlood=true;
                sim.StartMission(5,Difficulty.Standard);
                sim.ChooseChapterOption(0);sim.DispatchChapter(0);
                if(sim.ChapterNeedsSupport)sim.DispatchChapter(1,true);
                for(int i=0;i<4000 && sim.ChapterPhase==1 && sim.Result==SimResult.Active;i++)sim.Tick(.1f);
                EnterField();
            }
            Unit u=sim.Controlled;
            var pos=u?.pos??Vector3.zero;
            InspectState(Phase,Mode,Ammo,pos.x,pos.z,u?.yaw??0,FieldTouches.Count);
            if(Phase=="Playing" && !IsDuty)
            {
                var agent=sim.QuestAgent;
                var quest=sim.QuestMemory;
                Vector3 next=Vector3.zero;
                if(u!=null && (sim.ChapterPhase==1 || sim.ChapterPhase==3) && quest?.manual==u.id+1 &&
                    TryFieldNavigation(out _,out _,out Vector3 target))
                    next=sim.RouteWaypoint(u.pos,target);
                InspectQuest(sim.ChapterPhase,sim.ChapterChoice,agent?.id??-1,agent?.pos.x??0,agent?.pos.z??0,
                    sim.WingActive?1:0,quest?.stage??0,next.x,next.z,u!=null && quest?.manual==u.id+1?1:0);
            }
            if (!IsDuty && missionIndex==0 && sim.ColumnsActive)
            {
                var corner = u==null ? Vector3.zero : sim.ColumnNavigationStep(pos, sim.ColumnControlPoint(0));
                int boarded=0;
                for(int i=0;i<sim.ColumnMemberCount(0);i++) if(sim.ColumnMemberOutcome(0,i)==1)boarded++;
                int leader=sim.ColumnLeaderId(0);
                InspectMarket(leader,u?.id??-1,corner.x,corner.z,sim.MarketGateLift,boarded,
                    sim.ColumnsComplete?1:0,sim.MarketMeeting?1:0,sim.MarketWaiting(leader)?1:0,sim.Elapsed);
            }
            if(!IsDuty)return;
            bool intact=preparedFailure && normalRecord==PlayerPrefs.GetString("evac-suspend") &&
                normalCheckpoint==PlayerPrefs.GetString("evac-checkpoint");
            if(InspectDutyFailure(sim.Sector,expectedSector,intact?1:0)!=0 && !preparedFailure && Phase=="Playing" && DutyIndex==2)
            {
                normalRecord=PlayerPrefs.GetString("evac-suspend");
                normalCheckpoint=PlayerPrefs.GetString("evac-checkpoint");
                preparedFailure=true;
                expectedSector=sim.PrepareDutyCheckpointFailure();
            }
        }
    }
    public sealed partial class GameUI
    {
        [DllImport("__Internal")] static extern void InspectClick(string label);
        [DllImport("__Internal")] static extern void InspectHud(string action,string count,string banner,string mode,int frame);
        void ReportFieldHud(string action,string count,string banner)
        {
            if (Event.current.type==EventType.Repaint) InspectHud(action,count,banner,G.Mode,Time.frameCount);
        }
        [DllImport("__Internal")] static extern void InspectButton(string label,float x,float y,int frame);
        void ReportButton(Rect button,string label)
        {
            if(Event.current.type!=EventType.Repaint)return;
            var pt=button.center;
            InspectButton(label,(safeArea.x+pt.x*scale)/Screen.width,(Screen.height-safeArea.yMax+pt.y*scale)/Screen.height,Time.frameCount);
        }
    }
}
#endif
