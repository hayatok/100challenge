#if UNITY_EDITOR
using System;
using System.Linq;
using System.Text;
using UnityEngine;

namespace Evac
{
    public partial class GameSim
    {
        internal void VerifyChapterStages(StringBuilder report)
        {
            StartMission(3,Difficulty.Story);
            Verify(ChapterPhase==1 && !CanDepart,"Forward station before dispatch");
            Verify(ChooseChapterOption(0) && DispatchChapter(0),"Dispatch rescue detail");
            int people=state.units.Count;
            Verify(ChooseChapterOption(1) && ChooseChapterOption(0) && state.units.Count==people,
                "Changing the response reuses the available contact");
            Verify(DispatchChapter(0),"Reassign detail");
            for(int i=0;i<600 && ChapterRunner==null;i++)Tick(.1f);
            var carrier=ChapterRunner;
            Verify(carrier!=null && IsChapterResident(ChapterResident) && Possess(carrier.id),"Enter a live shoulder carry");
            Verify(!Shoot(Vector3.forward) && !Dodge(Vector3.right) && Save() && Load(),"Hands and pending rescue survive save");
            Verify(Controlled!=null && ChapterRunner==Controlled && !Shoot(Vector3.forward),"Restored physical carrier");
            Release();
            for(int i=0;i<600 && ChapterPhase==1;i++)Tick(.1f);
            Verify(ChapterPhase==2 && Chapter.frontContact=="夜勤の竹内" && HasChapterPost && ChapterPostStock==3,
                "Contact and physical clinic persist into evacuation");

            var medic=soldiers[0];medic.hp=31;medic.medkits=0;
            Verify(DispatchChapterSupply(medic.squad),"Assign forward medical supply");
            for(int i=0;i<500 && medic.hp<=31;i++)Tick(.1f);
            Verify(medic.hp>31 && ChapterPostStock<3,"A real supply crate treated a squad at the recorded site");
            Verify(LoadCheckpoint() && ChapterPhase==2 && ChapterPostStock==3,"Checkpoint restores start of evacuation");

            StartMission(1,Difficulty.Story);
            Verify(ChooseChapterOption(1) && DispatchChapter(0) && DispatchChapter(1,true),
                "Assign both signal stations");
            var sourceCrew=soldiers.Find(s=>s.squad==0);
            var endCrew=soldiers.Find(s=>s.squad==1);
            var source=ChapterPoint();
            var end=ChapterPoint(true);
            foreach(var s in soldiers) s.pos=Vector3.zero;
            sourceCrew.pos=source+Vector3.right*2.6f;
            Verify(QuestSignalStationReached(sourceCrew) && !QuestSignalReady &&
                QuestAgent?.squad==1 && QuestTarget(QuestAgent)==end,
                "Source is within interaction radius; marker follows the crew heading to the other station");
            sourceCrew.pos=Vector3.zero;
            endCrew.pos=end;
            Verify(!QuestSignalReady && QuestAgent?.squad==0 && QuestTarget(QuestAgent)==source,
                "If the other station fills first, marker switches back to the source");
            sourceCrew.pos=source;
            Verify(QuestSignalReady && UseChapterStation(sourceCrew,.1f) && ChapterPhase==2,
                "Both physical stations must be occupied for the two-crew relay");

            // Select an uncommon outcome: the chief operator is the sole remaining
            // active soldier when the two-station chapter switches to a portable set.
            StartMission(1,Difficulty.Story);
            foreach(var s in soldiers)if(s!=soldiers[0])s.active=false;
            Verify(ChooseChapterOption(1) && DispatchChapter(0),"Emergency single-person relay");
            sourceCrew=soldiers[0];
            sourceCrew.pos=ChapterPoint();
            end=ChapterPoint(true);
            Verify(QuestAgent==sourceCrew && !QuestSignalReady && !QuestSignalPortable &&
                UseChapterStation(sourceCrew,.1f) && QuestSignalPortable && !QuestSignalReady &&
                QuestTarget(QuestAgent)==end,
                "Portable relay retargets the lone operator to the other station before arrival");
            for(int i=0;i<1600 && ChapterPhase==1;i++)Tick(.1f);
            Verify(ChapterPhase==2 && HasChapterPost,"Single survivor can finish both signal stations");

            StartMission(0,Difficulty.Story);
            var scout=soldiers[0];
            Verify(Possess(scout.id) && CanTakeQuestDirectly && ChooseChapterOption(0) && TakeQuestDirectly() &&
                !CanTakeQuestDirectly && QuestAgent==null && FieldNavigation(scout).point==ChapterPoint(),
                "Unaffiliated first-person scout chooses and owns the physical survey");
            scout.pos=ChapterPoint();
            Verify(Interact() && Chapter.stage==1 && FieldNavigation(scout).point==ChapterPoint(),
                "Nearby interaction advances the solo scout to the next location");
            Release();
            Verify(DispatchChapter(0) && Possess(soldiers[1].id) && !CanTakeQuestDirectly,
                "A player entering elsewhere cannot claim a response already assigned to a squad");

            StartMission(0,Difficulty.Story);
            scout=soldiers[0];
            Verify(Possess(scout.id) && ChooseChapterOption(1) && TakeQuestDirectly() &&
                FieldNavigation(scout).destination==ChapterResident.name && FieldNavigation(scout).point==ChapterResident.pos,
                "Escort bearing initially names the shopkeeper and targets the person");
            scout.pos=ChapterResident.pos;
            Verify(Interact() && FieldNavigation(scout).destination=="バス停そばの合流地点" &&
                FieldNavigation(scout).point==ChapterPoint(),
                "After meeting the shopkeeper, bearing names and targets the rendezvous");

            StartMission(3,Difficulty.Story);
            Verify(ChooseChapterOption(0),"Prepare alternate failure");
            Damage(ChapterResident,999,Vector3.forward);
            Verify(Result==SimResult.Defeat && LoadCheckpoint() && ChapterPhase==1 && ChapterChoice<0,
                "Death of assigned contact restores the phase entrance and alternate choice");
            for(int operation=0;operation<4;operation++)
                for(int beat=0;beat<2;beat++)
                    for(int choice=0;choice<2;choice++)
                    {
                        StartMission(operation,Difficulty.Story);
                        if(beat==1)Chapter.phase=3;
                        int phase=ChapterPhase;
                        var objective=CurrentBeat.options[choice];
                        Verify(ChooseChapterOption(choice) && DispatchChapter(0),"Dispatch "+objective.title);
                        if(ChapterNeedsSupport && operation>0)Verify(DispatchChapter(1,true),"Complementary field station");
                        for(int step=0;step<3000 && ChapterPhase==phase && Result==SimResult.Active;step++)Tick(.1f);
                        Verify(Result==SimResult.Active && ChapterPhase!=phase && Chapter.earned==(int)objective.benefit+1,
                            "Both early chapter options must resolve: "+objective.title);
                    }
            report.AppendLine("All sixteen market/warehouse chapter responses reached their selected field outcome.");
            report.AppendLine("Signal markers follow the unoccupied station in either arrival order and retarget the portable relay.");
            report.AppendLine("Chapter phases: named rescue, handoff, occupied hands, suspended carry, physical aid post, lone operator, casualty and phase checkpoint passed.");
        }
    }
}
#endif
