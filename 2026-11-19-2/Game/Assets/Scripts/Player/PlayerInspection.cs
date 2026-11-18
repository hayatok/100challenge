#if UNITY_EDITOR || EVAC_INSPECTION
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        static string inspectionFolder;
        static bool filmRequested;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void InspectionSettings()
        {
            string[] args=Environment.GetCommandLineArgs();
            int index=Array.IndexOf(args,"-film");
            filmRequested=index>=0;
            if(!filmRequested)index=Array.IndexOf(args,"-campaign-inspection");
            if(index<0 || index+1>=args.Length)return;
            inspectionFolder=Path.GetFullPath(args[index+1]);
            Directory.CreateDirectory(inspectionFolder);
            EvacStorage.TestDirectory=Path.Combine(inspectionFolder,"saves-"+Guid.NewGuid().ToString("N"));
            Application.runInBackground=true;
        }
        static int benchmarkMinutes;
        void Start()
        {
            if(inspectionFolder==null)return;
            if(filmRequested){StartCoroutine(Film());return;}
            var args=Environment.GetCommandLineArgs();
            int i=Array.IndexOf(args,"-render-minutes");
            if(i>=0 && i+1<args.Length && int.TryParse(args[i+1],out benchmarkMinutes) && benchmarkMinutes>0)
                StartCoroutine(MeasureField(Mathf.Clamp(benchmarkMinutes,1,60)));
            else StartCoroutine(Inspect());
        }
        IEnumerator Film()
        {
            const int fps=24, width=960, height=540;
            string frames=Path.Combine(inspectionFolder,"frames");
            if(Directory.Exists(frames) && Directory.GetFileSystemEntries(frames).Length>0)
            {
                Debug.LogError("Film requires an empty frames directory: "+frames);
                Application.Quit(2);yield break;
            }
            Directory.CreateDirectory(frames);
            Screen.SetResolution(width,height,FullScreenMode.Windowed);
            for(int n=0;n<120 && (Screen.width!=width || Screen.height!=height);n++)yield return null;
            if(Screen.width!=width || Screen.height!=height){Debug.LogError("Film resolution unavailable");Application.Quit(2);yield break;}
            Time.captureFramerate=fps;
            using var mix=new FilmAudio(Path.Combine(inspectionFolder,"mix.wav"));
            if(!mix.Recording){Debug.LogError("Windows audio renderer could not start");Application.Quit(2);yield break;}
            sim.StartMission(4,Difficulty.Standard);
            EnterField();
            int chosen=0;
            for(int n=0;n<roster.Count;n++)if(roster[n].squad==0 && RosterAlive(n)){chosen=n;break;}
            int shotsBefore=roster[chosen].shots;
            Vector3 startPosition=default;
            float distance=0;
            var waitForPicture=new WaitForEndOfFrame();
            for(int frame=0;frame<15*fps;frame++)
            {
                yield return null;
                if(Phase!="Playing"){Debug.LogError("Film lost field simulation");Application.Quit(2);yield break;}
                if(frame==18){SelectSquad(1);SelectOrder((int)SquadOrder.Guide);IssueOrder(sim.ActiveAssembly);}
                if(frame==48){SelectSquad(0);SelectOrder((int)SquadOrder.Guard);IssueOrder(sim.ActiveGate);}
                if(frame==3*fps){SelectSoldier(chosen);Possess(chosen);startPosition=roster[chosen].pos;}
                if(frame>=3*fps && frame<12*fps)
                {
                    Unit pawn=sim.Controlled;
                    if(pawn==null){Debug.LogError("Film lost selected soldier");Application.Quit(2);yield break;}
                    Vector3 target=sim.ActiveAssembly;
                    if(frame>=5*fps)
                    {
                        float closest=float.PositiveInfinity;
                        foreach(var other in sim.Units)
                        {
                            if(!other.active||other.kind!=UnitKind.Infected)continue;
                            float d=(other.pos-pawn.pos).sqrMagnitude;
                            if(d<closest){closest=d;target=other.pos;}
                        }
                    }
                    Vector3 delta=target-pawn.pos;
                    float yaw=Mathf.MoveTowardsAngle(pawn.yaw,Mathf.Atan2(delta.x,delta.z)*Mathf.Rad2Deg,105f/fps);
                    float speed=frame<8*fps?.72f:0;
                    Vector3 before=pawn.pos;
                    sim.Move(Quaternion.Euler(0,yaw,0)*Vector3.forward*speed,yaw,1f/fps);
                    travelSpeed=(pawn.pos-before).magnitude*fps;
                    distance+=travelSpeed/fps;
                    stride+=travelSpeed*2.55f/fps;
                    if(frame>=7*fps && frame<10*fps && frame%8==0)FireOnce();
                    if(frame==10*fps)Reload();
                    FrameCamera(1f/fps,false);
                }
                if(frame==12*fps){CommandMode();SelectSquad(2);SelectOrder((int)SquadOrder.Engineer);IssueOrder(sim.EngineerDestination);}
                yield return waitForPicture;
                if(!mix.WriteFrame()){Debug.LogError("No game audio frame available");Application.Quit(2);yield break;}
                var image=ScreenCapture.CaptureScreenshotAsTexture();
                if(frame%fps==0)
                {
                    bool visible=false;
                    for(int y=1;y<5;y++)
                        for(int x=1;x<5;x++)
                            visible|=image.GetPixel(x*width/5,y*height/5).maxColorComponent>.06f;
                    if(!visible)
                    {
                        Debug.LogError("Film received a black frame. Start the Windows player in a visible window.");
                        Destroy(image);Application.Quit(2);yield break;
                    }
                }
                File.WriteAllBytes(Path.Combine(frames,frame.ToString("D4")+".jpg"),image.EncodeToJPG(91));
                Destroy(image);
            }
            int fired=roster[chosen].shots-shotsBefore;
            if(fired<1 || distance<1 || sim.Controlled!=null){Debug.LogError("Film did not complete gameplay actions");Application.Quit(2);yield break;}
            if(mix.Peak<.001f || Math.Abs(mix.Seconds-15)>.045)
            {Debug.LogError($"Invalid game mix: {mix.Seconds:F3} s, peak {mix.Peak:F4}");Application.Quit(2);yield break;}
            File.WriteAllText(Path.Combine(inspectionFolder,"film.txt"),
                $"Mission {MissionIndex}; soldier {roster[chosen].id}; shots {fired}; walked {distance:F2} m; displacement {(roster[chosen].pos-startPosition).magnitude:F2} m; final mode {Mode}; 360 frames at 24 fps; {width}x{height}; mix {mix.Seconds:F3} s, peak {mix.Peak:F4}.");
            Application.Quit(0);
        }
        IEnumerator MeasureField(int minutes)
        {
            var frames=new List<float>(minutes*3600);
            var tail=new List<float>(5000);
            var command=new List<float>();
            var direct=new List<float>();
            double start=Time.realtimeSinceStartupAsDouble,end=start+minutes*60;
            double restart=0, nextMode=start+12, nextRefill=0;
            bool firstPerson=false;
            int restarts=0,switches=0,maxVisible=0;
            while(Time.realtimeSinceStartupAsDouble<end)
            {
                double now=Time.realtimeSinceStartupAsDouble;
                bool newScene=now>=restart || Phase!="Playing";
                if(newScene)
                {
                    sim.StartMission(4,Difficulty.Standard);EnterField();
                    sim.PrepareCrowdInspection(true);mapCenter=Vector3.zero;zoom=32;
                    restart=now+45;restarts++;
                }
                if(now>=nextRefill)
                {
                    maxVisible=Mathf.Max(maxVisible,sim.PrepareCrowdInspection(false));nextRefill=now+.65;
                }
                if(now>=nextMode)
                {
                    firstPerson=!firstPerson;
                    nextMode=now+12;switches++;
                }
                if(firstPerson && sim.Controlled==null)
                {
                    for(int i=0;i<roster.Count;i++) if(roster[i].active){Possess(i);break;}
                }
                else if(!firstPerson && sim.Controlled!=null)CommandMode();
                bool renderedDirect=sim.Controlled!=null;
                yield return null;
                if(now-start<3)continue;
                float ms=Time.unscaledDeltaTime*1000;frames.Add(ms);
                (renderedDirect?direct:command).Add(ms);
                if(now>end-60)tail.Add(ms);
            }
            frames.Sort();tail.Sort();direct.Sort();command.Sort();
            if(direct.Count==0 || command.Count==0)throw new Exception("Stress run did not render both modes");
            float P(List<float> a,float q)=>a[Mathf.Clamp(Mathf.CeilToInt(q*a.Count)-1,0,a.Count-1)];
            File.WriteAllText(Path.Combine(inspectionFolder,"benchmark.txt"),
                $"Duration {minutes} min; {Screen.width}x{Screen.height}; {SystemInfo.graphicsDeviceName}; " +
                $"live infected maximum {maxVisible}; station resets {restarts}; camera switches {switches}; " +
                $"frames {frames.Count}; all p50 {P(frames,.5f):F2} ms p95 {P(frames,.95f):F2} ms p99 {P(frames,.99f):F2} ms; " +
                $"RTS {command.Count} frames p95 {P(command,.95f):F2} ms; FPS {direct.Count} frames p95 {P(direct,.95f):F2} ms; " +
                $"final minute p95 {P(tail,.95f):F2} ms; max {frames[frames.Count-1]:F2} ms.");
            Application.Quit(0);
        }
        IEnumerator Picture(string name)
        {
            yield return null;
            yield return new WaitForEndOfFrame();
            var image=ScreenCapture.CaptureScreenshotAsTexture();
            File.WriteAllBytes(Path.Combine(inspectionFolder,name+".jpg"),image.EncodeToJPG(90));
            Destroy(image);
        }
        IEnumerator Inspect()
        {
            yield return new WaitForSecondsRealtime(.6f);
            yield return Picture("title");
            Brief(0);yield return Picture("briefing");
            for(int m=0;m<8;m++)
            {
                Brief(m);Deploy();
                if(Phase!="Playing" || MissionIndex!=m) throw new Exception("Mission not playable: "+m);
                if(m==0||m==4)yield return Picture(m==0?"market-command":"station-command");
                if(m==0||m==4)
                {
                    int pick=m==0?0:Mathf.Min(3,RosterCount-1);
                    Possess(pick);var id=sim.Controlled.id;
                    FireOnce();Reload();
                    var pos=sim.Controlled.pos;
                    CommandMode();Possess(pick);
                    if (sim.Controlled.id!=id || sim.Controlled.pos!=pos) throw new Exception("Soldier state changed during transfer");
                    if(m==4)
                    {
                        var u=sim.Controlled;
                        var dir=sim.ActiveAssembly-u.pos;
                        sim.Move(Vector3.zero,Mathf.Atan2(dir.x,dir.z)*Mathf.Rad2Deg,0);
                    }
                    yield return new WaitForSecondsRealtime(.45f);
                    yield return Picture(m==0?"market-direct":"station-direct");
                    Pause();float paused=Elapsed;
                    yield return new WaitForSecondsRealtime(.17f);
                    if(paused!=Elapsed)throw new Exception("Pause advanced simulation");
                    if(m==4)yield return Picture("pause");
                    Resume();CommandMode();
                }
                int sector=-1;
                for(int i=0;i<11000&&sim.Result==SimResult.Active&&!sim.CanDepart;i++)
                {
                    if(sector!=sim.Sector)
                    {
                        sector=sim.Sector;
                        if(m>0)sim.Order(0,SquadOrder.Guard,sim.ActiveGate);
                        sim.Order(m==0?0:1,SquadOrder.Guide,sim.ActiveAssembly);
                        if(m>0)sim.Order(2,SquadOrder.Engineer,sim.EngineerDestination);
                    }
                    sim.Tick(.1f);
                }
                if(!sim.CanDepart)throw new Exception("Departure unavailable: "+sim.Mission.title+" "+sim.Objective);
                Depart();yield return new WaitForSecondsRealtime(3.35f);
                if(Phase!="Debrief"||!Won)throw new Exception("Missing debrief "+m);
                if(m==0)yield return Picture("debrief");
                DebriefNext();
            }
            if(Phase!="Ending")throw new Exception("No ending");
            yield return Picture("ending");
            int campaignTotal=CampaignRescued;
            Home();
            for(int district=0;district<4;district++)
            {
                StartDuty(district);
                if(Phase!="Playing" || !IsDuty || DutyIndex!=district || string.IsNullOrEmpty(CurrentDutyTitle))
                    throw new Exception("Missing duty briefing handoff: "+district);
                if(district==2)yield return Picture("station-duty");
                Pause();float atPause=Elapsed;Home();
                if(!HasDutySave || !CanContinue)throw new Exception("Duty save replaced main campaign");
                ContinueDuty();
                if(DutyIndex!=district || Mathf.Abs(Elapsed-atPause)>.11f)throw new Exception("Duty resume failed: "+district);
                Home();
            }
            File.WriteAllText(Path.Combine(inspectionFolder,"verified.txt"),
                $"Reached ending via eight briefings, dispatches and debriefings. Campaign rescued {campaignTotal}. " +
                $"Entered and resumed all four independent duties. Screen {Screen.width}x{Screen.height}. " +
                $"Graphics {SystemInfo.graphicsDeviceName}. Touch layout {TouchUI}.");
            Application.Quit(0);
        }
    }
    public partial class GameSim
    {
        internal int PrepareCrowdInspection(bool spread)
        {
            SpawnWave(150);
            int n=0;
            foreach(var u in Units)
            {
                if(u.kind!=UnitKind.Infected||!u.active)continue;
                if(spread)u.pos=new Vector3((n%12-5.5f)*1.8f,0,(n/12-5)*2.5f);
                u.visible=true;n++;
            }
            return n;
        }
    }
}
#endif
