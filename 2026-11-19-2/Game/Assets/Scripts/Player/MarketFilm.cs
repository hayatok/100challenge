#if UNITY_EDITOR || EVAC_INSPECTION
using System;
using System.Collections;
using System.IO;
using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        static bool marketFilmRequested;
        static readonly Vector3 MarketFilmApproach=new Vector3(-4.35f,0,.65f);
        static readonly Vector3 MarketFilmDoor=new Vector3(-7,0,-4.6f);

        bool PrepareMarketFilm()
        {
            sim.StartMission(0,Difficulty.Standard);
            if(!sim.ChooseChapterOption(0) || !sim.DispatchChapter(0))return false;
            for(int i=0;i<1800 && sim.ChapterPhase==1 && sim.Result==SimResult.Active;i++)sim.Tick(.1f);
            sim.Tick(.1f);
            if(!sim.ColumnsActive)return false;
            sim.Order(0,SquadOrder.Move,MarketFilmApproach);
            for(int i=0;i<100;i++)sim.Tick(.1f);
            if(!sim.ColumnsActive || sim.Result!=SimResult.Active)return false;
            EnterField();
            ui.FoldMarketFilmPanels();
            LocateColumn(0);
            mapCenter=new Vector3(-6,0,-.25f);
            zoom=9f;
            FrameCamera(0,true);
            return true;
        }

        IEnumerator MarketFilm()
        {
            const int rate=24, seconds=30, frameCount=rate*seconds, directFrame=99, commandFrame=260;
            string frames=Path.Combine(inspectionFolder,"frames");
            if(Directory.Exists(frames) && Directory.GetFileSystemEntries(frames).Length!=0)
            {Debug.LogError("Market film requires an empty frames directory");Application.Quit(2);yield break;}
            Directory.CreateDirectory(frames);
            Screen.SetResolution(960,540,FullScreenMode.Windowed);
            for(int i=0;i<120 && (Screen.width!=960 || Screen.height!=540);i++)yield return null;
            if(Screen.width!=960 || Screen.height!=540 || !PrepareMarketFilm())
            {
                Debug.LogError($"Unable to reach the morning market column: {Screen.width}x{Screen.height}; "+
                    $"chapter {sim.ChapterPhase}, columns {sim.ColumnCount}, result {sim.Result}, elapsed {sim.Elapsed:F1}.");
                Application.Quit(2);yield break;
            }
            Time.captureFramerate=rate;
            using var mix=new FilmAudio(Path.Combine(inspectionFolder,"mix.wav"));
            if(!mix.Recording){Debug.LogError("Unable to capture the market game audio");Application.Quit(2);yield break;}

            var first=sim.Find(sim.ColumnMemberId(0,0));
            var second=sim.Find(sim.ColumnMemberId(0,1));
            int guideId=-1, openerId=-1, opened=-1;
            int[] passed={-1,-1};
            int boardFrame=-1;
            var frameEnd=new WaitForEndOfFrame();
            for(int frame=0;frame<frameCount;frame++)
            {
                yield return null;
                if(Phase!="Playing"){Debug.LogError("The market operation ended during capture");Application.Quit(2);yield break;}
                if(frame==8){SelectSquad(0);ui.OpenColumn(0);}
                if(frame==56)
                {
                    if(!ColumnAction(0,1)){Debug.LogError("Unable to assign the covered market route");Application.Quit(2);yield break;}
                    guideId=sim.ColumnLeaderId(0);
                    ui.CloseFieldOverlay();
                }
                if(frame==directFrame)
                {
                    openerId=sim.MarketGateCrew(0);
                    PossessMarketOpener(openerId);
                    if(sim.Controlled==null || openerId==guideId)
                    {Debug.LogError($"Unable to possess a separate gate operator (guide #{guideId}, opener #{openerId})");Application.Quit(2);yield break;}
                }
                if(frame>=directFrame && frame<commandFrame && sim.Controlled is Unit pawn)
                {
                    Vector3 actionPoint=sim.ColumnControlPoint(0);
                    Vector3 delta=sim.RouteWaypoint(pawn.pos,actionPoint)-pawn.pos;
                    bool atPanel=CanOpenLocalMarketGate;
                    Vector3 focus=Vector3.Lerp(MarketFilmDoor,sim.ColumnPosition(0),opened<0?.26f:.38f)-pawn.pos;
                    float yaw=Mathf.MoveTowardsAngle(pawn.yaw,Mathf.Atan2(focus.x,focus.z)*Mathf.Rad2Deg,160f/rate);
                    pitch=Mathf.MoveTowards(pitch,4,34f/rate);
                    var before=pawn.pos;
                    sim.Move(opened<0 && !atPanel?Vector3.ClampMagnitude(delta,.65f):Vector3.zero,yaw,1f/rate);
                    travelSpeed=Vector3.Distance(before,pawn.pos)*rate;
                    stride+=travelSpeed*2.55f/rate;
                    if(opened<0 && frame>=153 && atPanel){
                        TryAction();
                        if(sim.ColumnControlOpen(0))opened=frame;
                    }
                    FrameCamera(1f/rate,false);
                }
                if(frame==commandFrame){CommandMode();mapCenter=new Vector3(3.5f,0,-12.8f);zoom=9.6f;}
                if(frame>=commandFrame+24)
                {
                    mapCenter=Vector3.Lerp(mapCenter,Vector3.Lerp(sim.ColumnPosition(0),sim.ActiveExit,.32f),.028f);
                    FrameCamera(1f/rate,false);
                }
                if(passed[0]<0 && first.pos.z<MarketFilmDoor.z && Mathf.Abs(first.pos.x-MarketFilmDoor.x)<1.15f)passed[0]=frame;
                if(passed[1]<0 && second.pos.z<MarketFilmDoor.z && Mathf.Abs(second.pos.x-MarketFilmDoor.x)<1.15f)passed[1]=frame;
                if(boardFrame<0 && sim.ColumnMemberOutcome(0,0)==1 && sim.ColumnMemberOutcome(0,1)==1)boardFrame=frame;

                yield return frameEnd;
                if(!mix.WriteFrame()){Debug.LogError("Missing market audio frame");Application.Quit(2);yield break;}
                var img=ScreenCapture.CaptureScreenshotAsTexture();
                bool visible=false;
                for(int x=1;x<5;x++)for(int y=1;y<5;y++)visible|=img.GetPixel(x*img.width/5,y*img.height/5).maxColorComponent>.06f;
                if(!visible){Destroy(img);Debug.LogError("Black market frame "+frame);Application.Quit(2);yield break;}
                File.WriteAllBytes(Path.Combine(frames,frame.ToString("D4")+".jpg"),img.EncodeToJPG(90));
                Destroy(img);
            }
            string record=$"Market standard; guide #{guideId}; local operator #{openerId}; gate opened frame {opened}; "+
                $"{first.name} at {first.pos} passed frame {passed[0]} outcome {sim.ColumnMemberOutcome(0,0)}; "+
                $"{second.name} at {second.pos} passed frame {passed[1]} outcome {sim.ColumnMemberOutcome(0,1)}; boarded frame {boardFrame}; "+
                $"RTS → FPS {directFrame} / FPS → RTS {commandFrame}; {frameCount} frames at {rate} fps, 960x540; audio {mix.Seconds:F3} s peak {mix.Peak:F4}.";
            File.WriteAllText(Path.Combine(inspectionFolder,"film.txt"),record);
            if(opened<0 || passed[0]<0 || passed[1]<0 || Math.Abs(mix.Seconds-seconds)>.05 || mix.Peak<.001f)
            {Debug.LogError(record);Application.Quit(2);yield break;}
            Application.Quit(0);
        }
    }

    public sealed partial class GameUI
    {
        internal void FoldMarketFilmPanels()
        {
            commandPanel = CommandPanel.None;
        }
    }
}
#endif
