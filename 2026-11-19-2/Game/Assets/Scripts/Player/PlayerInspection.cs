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
            if(!filmRequested){index=Array.IndexOf(args,"-column-film");columnFilmRequested=index>=0;}
            if(index<0){index=Array.IndexOf(args,"-market-film");marketFilmRequested=index>=0;}
            if(index<0)index=Array.IndexOf(args,"-campaign-inspection");
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
            if(marketFilmRequested){StartCoroutine(MarketFilm());return;}
            if(columnFilmRequested){StartCoroutine(ColumnFilm());return;}
            if(filmRequested){StartCoroutine(Film());return;}
            var args=Environment.GetCommandLineArgs();
            int i=Array.IndexOf(args,"-render-minutes");
            if(i>=0 && i+1<args.Length && int.TryParse(args[i+1],out benchmarkMinutes) && benchmarkMinutes>0)
                StartCoroutine(MeasureField(Mathf.Clamp(benchmarkMinutes,1,60)));
            else StartCoroutine(Inspect());
        }
        bool PrepareClinicFilm(out int selected)
        {
            selected=-1;
            sim.StartMission(1,Difficulty.Story);
            if(!sim.ChooseChapterOption(0) || !sim.DispatchChapter(0))return false;
            for(int i=0;i<2000 && sim.ChapterPhase==1;i++)sim.Tick(.1f);
            if(sim.ChapterPhase!=2)return false;
            sim.Order(0,SquadOrder.Guard,sim.ActiveGate);
            sim.Order(1,SquadOrder.Guide,sim.ActiveAssembly);
            sim.Order(2,SquadOrder.Engineer,sim.ActiveWorks);
            if(!sim.DispatchDistrict(0,0,false))return false;
            for(int i=0;i<3500 && !sim.WingActive && sim.Result==SimResult.Active;i++)sim.Tick(.1f);
            if(!sim.WingActive || !sim.DispatchWing(0,0,0) || !sim.DispatchWing(2,1,0))return false;
            for(int i=0;i<1800 && (!sim.WingStationDone(0) || !sim.WingStationDone(1));i++)sim.Tick(.1f);
            if(!sim.DispatchWing(2,2,0))return false;
            for(int i=0;i<900 && !sim.WingStationDone(2);i++){
                sim.Tick(.08f);
                float gap=Vector3.Distance(sim.WingFreightPosition,sim.WingPosition(2));
                if(gap<10 && gap>4 && sim.WingHasFreight)break;
            }
            if(!sim.WingHasFreight || sim.WingStationDone(2))return false;
            EnterField();
            float nearest=float.PositiveInfinity;
            for(int i=0;i<roster.Count;i++){
                var u=roster[i];
                if(!u.active || u.squad!=2)continue;
                float distance=(u.pos-sim.WingFreightPosition).sqrMagnitude;
                if(distance<nearest){nearest=distance;selected=i;}
            }
            if(selected<0 || nearest>16)return false;
            // Hold this forward crew while the command shot establishes the ward.
            sim.Order(2,SquadOrder.Move,roster[selected].pos);
            SelectSoldier(selected);LocateWing(2);FrameCamera(0,true);
            return true;
        }

        IEnumerator Film()
        {
            const int fps=24, width=960, height=540;
            string frames=Path.Combine(inspectionFolder,"frames");
            if(Directory.Exists(frames) && Directory.GetFileSystemEntries(frames).Length>0)
            {Debug.LogError("Film requires an empty frames directory");Application.Quit(2);yield break;}
            Directory.CreateDirectory(frames);
            Screen.SetResolution(width,height,FullScreenMode.Windowed);
            for(int n=0;n<120 && (Screen.width!=width || Screen.height!=height);n++)yield return null;
            if(Screen.width!=width || Screen.height!=height || !PrepareClinicFilm(out int chosen))
            {Debug.LogError("Unable to reach the clinic with its assigned equipment");Application.Quit(2);yield break;}
            Time.captureFramerate=fps;
            using var mix=new FilmAudio(Path.Combine(inspectionFolder,"mix.wav"));
            if(!mix.Recording){Debug.LogError("No recording device for the game mix");Application.Quit(2);yield break;}
            var medic=roster[chosen];
            var patient=sim.Find(sim.WingResidentId);
            Vector3 firstPatient=patient.pos,firstMedic=medic.pos,firstOxygen=sim.WingFreightPosition;
            int rescuedFrame=-1;float distance=0;
            var frameEnd=new WaitForEndOfFrame();
            for(int frame=0;frame<15*fps;frame++){
                yield return null;
                if(Phase!="Playing"){Debug.LogError("Lost the live operation");Application.Quit(2);yield break;}
                if(frame==8){SelectSoldier(chosen);LocateWing(2);sound.Signal("dispatch");}
                if(frame==42){Possess(chosen);if(sim.CanTakeWingFreight)sim.WingTakeCart();}
                if(frame>=42 && frame<308){
                    if(sim.Controlled!=medic){Debug.LogError("Lost assigned field specialist");Application.Quit(2);yield break;}
                    Vector3 goal=sim.WingPosition(rescuedFrame<0?2:4);
                    Vector3 waypoint=sim.RouteWaypoint(medic.pos,goal);
                    Vector3 heading=waypoint-medic.pos;
                    bool lookAtPatient=rescuedFrame>=0 && (frame-rescuedFrame<32 || frame>267);
                    Vector3 view=lookAtPatient?patient.pos-medic.pos:heading;
                    float yaw=view.sqrMagnitude>.01f?Mathf.MoveTowardsAngle(medic.yaw,Mathf.Atan2(view.x,view.z)*Mathf.Rad2Deg,155f/fps):medic.yaw;
                    Vector3 before=medic.pos;
                    Vector3 walk=lookAtPatient?Vector3.zero:Vector3.ClampMagnitude(heading*(fps/5.3f),.76f);
                    sim.Move(walk,yaw,1f/fps);
                    travelSpeed=(medic.pos-before).magnitude*fps;distance+=travelSpeed/fps;stride+=travelSpeed*2.55f/fps;
                    if(rescuedFrame<0 && HandleWing(2,0))rescuedFrame=frame;
                    FrameCamera(1f/fps,false);
                }
                if(frame==308){CommandMode();LocateWing(4);SelectSquad(2);HandleWing(4,0);}
                yield return frameEnd;
                if(!mix.WriteFrame()){Debug.LogError("No game audio frame");Application.Quit(2);yield break;}
                var image=ScreenCapture.CaptureScreenshotAsTexture();
                bool visible=false;
                for(int y=1;y<5;y++)for(int x=1;x<5;x++)visible|=image.GetPixel(x*width/5,y*height/5).maxColorComponent>.06f;
                if(!visible){Destroy(image);Debug.LogError("Black film frame "+frame);Application.Quit(2);yield break;}
                File.WriteAllBytes(Path.Combine(frames,frame.ToString("D4")+".jpg"),image.EncodeToJPG(91));
                Destroy(image);
            }
            float followed=Vector3.Distance(firstPatient,patient.pos);
            string detail=$"Mission {MissionIndex}; {sim.WingTitle}; soldier {medic.name} #{medic.id}; RTS→FPS frame 42, FPS→RTS frame 308; walked {distance:F2} m; net {Vector3.Distance(medic.pos,firstMedic):F2} m; oxygen moved {Vector3.Distance(firstOxygen,sim.WingFreightPosition):F2} m; {patient.name} assisted at frame {rescuedFrame}, moved {followed:F2} m; end {Mode}; 360 frames, 24 fps, {width}x{height}; mix {mix.Seconds:F3} s peak {mix.Peak:F4}.";
            File.WriteAllText(Path.Combine(inspectionFolder,"film.txt"),detail);
            if(rescuedFrame<0 || distance<9 || followed<2 || sim.Controlled!=null || mix.Peak<.001f || Math.Abs(mix.Seconds-15)>.045){
                Debug.LogError("Film outcome incomplete: "+detail);Application.Quit(2);yield break;
            }
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
                yield return null;
                yield return new WaitForEndOfFrame();
                if(Phase!="Playing" || MissionIndex!=m) throw new Exception("Mission not playable: "+m);
                if(m==0||m==4)yield return Picture(m==0?"market-command":"station-command");
                if(m==3 || m==7)
                {
                    Possess(0);
                    var pawn=sim.Controlled;
                    var toward=sim.ActiveAssembly-pawn.pos;
                    sim.Move(Vector3.zero,Mathf.Atan2(toward.x,toward.z)*Mathf.Rad2Deg,0);
                    yield return new WaitForSecondsRealtime(.72f);
                    yield return Picture(m==3?"freight-night":"depot-night");
                    CommandMode();
                }
                if(m==1)
                {
                    ui.SearchHotkey();yield return Picture("operation-book");ui.CloseFieldOverlay();
                    ChooseResponse(1);SelectSquad(0);AssignResponse(false);SelectSquad(1);AssignResponse(true);
                    if(!sim.ChapterNeedsSupport || sim.ChapterAssigned(1)!=1 || (mapCenter-sim.ChapterPoint(true)).sqrMagnitude>.01f)
                        throw new Exception("Supporting team did not receive its own signal location");
                    ui.SearchHotkey();yield return Picture("signal-support-map");ui.CloseFieldOverlay();
                    ui.InspectDispatchPanel();yield return Picture("district-desk");ui.CloseFieldOverlay();
                    InspectDistrict(sim.Sector); FrameCamera(0,true);
                    yield return Picture("northern-approach");
                }
                if(m==2)
                {
                    ui.InspectFleetPanel();yield return Picture("fleet-desk");ui.CloseFieldOverlay();
                }
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
                bool drewWing=false, enteredWing=false, sawColumns=false, sawStretcher=false;
                for(int i=0;i<14000&&sim.Result==SimResult.Active&&!sim.CanDepart;i++)
                {
                    if(sim.ChapterPhase==1 || sim.ChapterPhase==3)
                    {
                        if(sim.ChapterChoice<0)
                        {
                            sim.ChooseChapterOption((m+sim.ChapterPhase)%2);
                            sim.DispatchChapter(0);
                            if(sim.ChapterNeedsSupport && m>0)sim.DispatchChapter(1,true);
                        }
                        sim.Tick(.1f);
                        continue;
                    }
                    if(sector!=sim.Sector)
                    {
                        sector=sim.Sector;
                        if(m>0)sim.Order(0,SquadOrder.Guard,sim.ActiveGate);
                        sim.Order(m==0?0:1,SquadOrder.Guide,sim.ActiveAssembly);
                        if(m>0)sim.Order(2,SquadOrder.Engineer,sim.EngineerDestination);
                    }
                    sim.DriveWingInspection();
                    sim.DriveColumnInspection();
                    if(sim.ColumnsActive && !sawColumns)
                    {
                        sawColumns=true;LocateColumn(0);FrameCamera(0,true);
                        yield return new WaitForEndOfFrame();
                        ui.OpenColumn(0);yield return Picture(m==5?"flood-column-ledger":"market-column-ledger");
                        ui.CloseFieldOverlay();
                        yield return Picture(m==5?"flood-column-command":"market-column-command");
                    }
                    if(m==5 && !sawStretcher && sim.ColumnsActive && sim.ColumnCarrierId(1)>=0 && sim.ColumnCarriedId(1)>=0)
                    {
                        int carrier=roster.FindIndex(s=>s.id==sim.ColumnCarrierId(1));
                        if(carrier>=0)
                        {
                            sawStretcher=true;Possess(carrier);pitch=19;
                            yield return new WaitForSecondsRealtime(.75f);
                            yield return Picture("stretcher-direct");
                            CommandMode();zoom=5;
                            yield return new WaitForSecondsRealtime(.70f);
                            yield return Picture("stretcher-command");
                        }
                    }
                    if(sim.WingActive && m%2==0)
                    {
                        if(!drewWing)
                        {
                            drewWing=true;LocateWing(0);FrameCamera(0,true);
                            yield return new WaitForEndOfFrame();
                            ui.OpenWing(0);yield return Picture("wing-"+m+"-plan");
                            if(!ui.FieldOverlay)throw new Exception("Building floor plan did not stay open: "+m);
                            ui.CloseFieldOverlay();
                        }
                        if(!enteredWing && !sim.WingComplete)
                        {
                            int pick=roster.FindIndex(s=>s.active && Mathf.Abs(s.pos.x)>5 && s.pos.z>=116 && s.pos.z<124);
                            if(pick>=0)
                            {
                                enteredWing=true;Possess(pick);
                                sim.Move(Vector3.zero,roster[pick].pos.x<0?-77:77,0);
                                yield return new WaitForSecondsRealtime(.68f);
                                yield return Picture("wing-"+m+"-direct");
                                CommandMode();yield return new WaitForSecondsRealtime(.65f);
                                yield return Picture("wing-"+m+"-command");
                            }
                        }
                    }
                    if(sim.FleetDecisionPending)sim.ResolveFleetBlock(false);
                    if(sim.DistrictOutcome(sim.Sector)==0 && sim.DistrictAssignment(0)<0 && (m>0 || sim.Boarded>=sim.SectorGoal))
                        sim.DispatchDistrict(0,sim.Sector,(m+sim.Sector)%2==0);
                    sim.Tick(.1f);
                }
                if((m==0 || m==5) && !sawColumns)throw new Exception("Missing evacuation column: "+m);
                if(!sim.CanDepart)throw new Exception("Departure unavailable: "+sim.Mission.title+" "+sim.Objective+" "+sim.WingStatus);
                if(m%2==0 && (!drewWing || !enteredWing))throw new Exception("Unverified building entry: "+m);
                Depart();
                float until=Time.realtimeSinceStartup+24;
                while(Phase=="Playing" && Time.realtimeSinceStartup<until)yield return null;
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
