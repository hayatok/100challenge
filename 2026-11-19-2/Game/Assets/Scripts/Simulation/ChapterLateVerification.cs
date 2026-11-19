#if UNITY_EDITOR
using System;
using System.Text;

namespace Evac
{
    public partial class GameSim
    {
        internal void VerifyLateResponses(StringBuilder report)
        {
            for(int mission=4;mission<8;mission++)
                for(int beat=0;beat<2;beat++)
                    for(int choice=0;choice<2;choice++)
                    {
                        StartMission(mission,Difficulty.Story);
                        if(beat==1) Chapter.phase=3;
                        int phase=ChapterPhase;
                        var expected=(beat==0?ChapterCatalog.For(mission).forward:ChapterCatalog.For(mission).retreat).options[choice];
                        if(!ChooseChapterOption(choice) || !DispatchChapter(0))throw new Exception("Response not dispatchable: "+expected.title);
                        if(ChapterNeedsSupport && !DispatchChapter(1,true))throw new Exception("Relay support missing: "+expected.title);
                        if(ChapterResident!=null && string.IsNullOrEmpty(ChapterResident.name))throw new Exception("Missing rescue identity");
                        float start=Elapsed;
                        for(int i=0;i<3600 && ChapterPhase==phase && Result==SimResult.Active;i++)Tick(.1f);
                        if(ChapterPhase==phase || Result!=SimResult.Active || Chapter.earned!=(int)expected.benefit+1)
                            throw new Exception("Unresolved chapter response: "+expected.title+" / "+ChapterInstruction);
                        if(Elapsed-start<.1f)throw new Exception("Response resolved without field work");
                        if(beat==0 && (!HasChapterPost || ChapterPostStock<1))throw new Exception("Forward post missing");
                    }
            report.AppendLine("All sixteen alternate rail/yard chapter responses reached the chosen consequence through field movement.");
        }
    }
}
#endif
