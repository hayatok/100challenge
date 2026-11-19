#if UNITY_EDITOR || EVAC_INSPECTION
using System;
using System.Collections;
using System.IO;
using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        static bool columnFilmRequested;

        bool PrepareColumnFilm(out int selected)
        {
            selected=-1;
            sim.StartMission(5,Difficulty.Story);
            if(!sim.ChooseChapterOption(0) || !sim.DispatchChapter(0))return false;
            for(int i=0;i<1800 && sim.ChapterPhase==1;i++)sim.Tick(.1f);
            sim.Tick(.1f);
            if(!sim.ColumnsActive)return false;
            sim.Order(0,SquadOrder.Guard,sim.ActiveGate);
            sim.Order(1,SquadOrder.Guide,sim.ActiveAssembly);
            sim.Order(2,SquadOrder.Engineer,sim.ActiveWorks);
            if(!sim.CommandColumn(0,0,0) || !sim.CommandColumn(1,1,1) || !sim.CommandColumn(1,4,2))return false;
            var patient=sim.Find(sim.ColumnMemberId(1,1));
            var guide=sim.Find(sim.ColumnLeaderId(1));
            if(patient==null || guide==null)return false;
            for(int i=0;i<1500 && Vector3.Distance(guide.pos,patient.pos)>2.3f && sim.Result==SimResult.Active;i++)sim.Tick(.1f);
            if(Vector3.Distance(guide.pos,patient.pos)>2.5f || !sim.CommandColumn(1,2,1))return false;
            sim.Order(1,SquadOrder.Move,patient.pos);
            EnterField();
            selected=roster.FindIndex(u=>u==guide);
            if(selected<0)return false;
            SelectSoldier(selected);LocateColumn(1);FrameCamera(0,true);
            return true;
        }

        IEnumerator ColumnFilm()
        {
            const int rate=24, count=18*rate;
            string frames=Path.Combine(inspectionFolder,"frames");
            if(Directory.Exists(frames) && Directory.GetFileSystemEntries(frames).Length!=0)
            {Debug.LogError("Column film requires a new output directory");Application.Quit(2);yield break;}
            Directory.CreateDirectory(frames);
            Screen.SetResolution(960,540,FullScreenMode.Windowed);
            for(int i=0;i<120 && (Screen.width!=960 || Screen.height!=540);i++)yield return null;
            if(Screen.width!=960 || Screen.height!=540 || !PrepareColumnFilm(out int chosen))
            {Debug.LogError("Unable to reach the two columns in ordinary campaign play");Application.Quit(2);yield break;}
            Time.captureFramerate=rate;
            using var mix=new FilmAudio(Path.Combine(inspectionFolder,"mix.wav"));
            if(!mix.Recording){Debug.LogError("Unable to capture actual game audio");Application.Quit(2);yield break;}
            var pawn=roster[chosen];var patient=sim.Find(sim.ColumnMemberId(1,1));
            Vector3 patientStart=patient.pos;float distance=0,maxFront=0;int pickup=-1;
            var end=new WaitForEndOfFrame();
            for(int frame=0;frame<count;frame++){
                yield return null;
                if(Phase!="Playing"){Debug.LogError("Column film lost the running operation");Application.Quit(2);yield break;}
                if(frame==9)ui.OpenColumn(1);
                if(frame==64){ui.CloseFieldOverlay();SelectSoldier(chosen);LocateColumn(1);}
                if(frame==72){Possess(chosen);pitch=9;}
                if(frame>=72 && frame<369){
                    if(sim.Controlled!=pawn){Debug.LogError("Column film lost its selected operator");Application.Quit(2);yield break;}
                    if(frame>=82 && pickup<0 && sim.CanCommandColumn(1,7,pawn.squad)){
                        if(ColumnAction(1,7) && sim.ColumnCarriedId(1)==patient.id){
                            pickup=frame;ColumnAction(1,1);
                        }
                    }
                    Vector3 goal=pickup<0?patient.pos:sim.ColumnDestination(1);
                    Vector3 delta=sim.RouteWaypoint(pawn.pos,goal)-pawn.pos;
                    float targetYaw=Mathf.Atan2(delta.x,delta.z)*Mathf.Rad2Deg;
                    float yaw=Mathf.MoveTowardsAngle(pawn.yaw,targetYaw,95f/rate);
                    pitch=Mathf.MoveTowards(pitch,pickup<0?13:frame<162?42:19,34f/rate);
                    var before=pawn.pos;
                    var input=frame<93 || delta.sqrMagnitude<.001f?Vector3.zero:Vector3.ClampMagnitude(delta*(rate/2.7f),.90f);
                    sim.Move(input,yaw,1f/rate);
                    travelSpeed=Vector3.Distance(before,pawn.pos)*rate;distance+=travelSpeed/rate;stride+=travelSpeed*2.55f/rate;
                    maxFront=Mathf.Max(maxFront,Vector3.Dot(patient.pos-pawn.pos,Quaternion.Euler(0,yaw,0)*Vector3.forward));
                    FrameCamera(1f/rate,false);
                }
                if(frame==369){CommandMode();LocateColumn(1);}
                yield return end;
                if(!mix.WriteFrame()){Debug.LogError("Missing audio frame");Application.Quit(2);yield break;}
                var img=ScreenCapture.CaptureScreenshotAsTexture();bool visible=false;
                for(int x=1;x<5;x++)for(int y=1;y<5;y++)visible|=img.GetPixel(x*img.width/5,y*img.height/5).maxColorComponent>.06f;
                if(!visible){Destroy(img);Debug.LogError("Black captured frame "+frame);Application.Quit(2);yield break;}
                File.WriteAllBytes(Path.Combine(frames,frame.ToString("D4")+".jpg"),img.EncodeToJPG(91));Destroy(img);
            }
            float displacement=Vector3.Distance(patientStart,patient.pos);
            string record=$"Mission {MissionIndex+1}; {sim.ColumnTitle(0)} and {sim.ColumnTitle(1)}; {pawn.name} #{pawn.id} took {patient.name} #{patient.id} at frame {pickup}; map → FPS 72 / FPS → map 369; walked {distance:F2} m; patient displacement {displacement:F2} m; patient forward offset {maxFront:F2} m; final {Mode}; {count} frames at {rate} fps, 960x540; game mix {mix.Seconds:F3} s peak {mix.Peak:F4}.";
            File.WriteAllText(Path.Combine(inspectionFolder,"film.txt"),record);
            if(pickup<0 || distance<5 || displacement<4 || maxFront<.8f || sim.Controlled!=null || Math.Abs(mix.Seconds-18)>.05 || mix.Peak<.001f){
                Debug.LogError(record);Application.Quit(2);yield break;
            }
            Application.Quit(0);
        }
    }
}
#endif
