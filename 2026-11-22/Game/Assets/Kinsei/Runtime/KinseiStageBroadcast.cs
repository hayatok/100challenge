using UnityEngine;

public sealed partial class KinseiSession
{
    static readonly Vector3 StageMicrophone=new(-5,StageFloor,3.4f);
    static readonly Vector3 StageDeskPost=new(-1.35f,0,.70f);
    static readonly Vector3 StageDeskCentre=new(-1.90f,.91f,1.05f);
    const string AirStageWords="マイクを開いて兄貴分の話を町内へ流す";
    Person stageDeskRunner;
    bool stageReturned,stageDeskAnnounced,stageFeedLive;
    Vector3 speakerMark;
    float nextStageFrame,stageLevelStarted;

    bool StageSpeaking=>stageBeat==StageBeat.ToMicrophone || stageBeat==StageBeat.Testimony;
    const float StageLevelSet=1.22f;
    bool StageDeskReady=>stageDeskRunner!=null && stageDeskRunner.hp>0 &&
        stageDeskAnnounced && clock-stageLevelStarted>=StageLevelSet;

    void OrderStageDesk()
    {
        if(!StageActive || !command || StageSpeaking || stageBeat==StageBeat.Settled)return;
        int members=SelectedMembers;
        if(CountMembers(members)!=1){Say("実況係を一人選んでください");return;}
        SetSelection(members);
        var member=crew[chosen];
        if(member==stageWitness){Say(member.name+"「わしは袖で見届ける。実況は別のもんに頼む」");return;}
        if(member==stageDeskRunner){
            ClearStageDesk();Say(member.name+"が実況卓の担当を外れた");return;
        }
        if(member.duty==Duty.Attend || member.duty==Duty.Backstage || member.duty==Duty.BoxOffice){
            Say(member.name+"は別の仕事中。ほかの組員を選んでください");return;
        }
        if(!walkways.Ready || !walkways.GetPath(member.Position,StageDeskPost,searchPath)){
            Say("実況卓までの通路がつながっていない");return;
        }
        ClearStageDesk();stageDeskRunner=member;member.path=null;
        Say(member.name+"「袖の実況卓につくで」");sound.Cue("dial");Mark("stage-desk-order-"+chosen);
    }

    void ClearStageDesk()
    {
        if(stageDeskRunner!=null){
            stageDeskRunner.path=null;
            if(stageDeskRunner.hp>0)Motion(stageDeskRunner,"idle");
        }
        if(club)club.SetStageLevel(0);
        stageDeskRunner=null;stageDeskAnnounced=false;
        if(stageFeedLive){
            sound.StopStageTestimony();club.SetStageBroadcast(false);club.SetStageMonitor(null);club.SetExchangePicture(null);
            stageFeedLive=false;
        }
    }

    void TickStageDesk(float dt)
    {
        if(stageDeskRunner==null)return;
        if(stageDeskRunner.hp<=0){
            ClearStageDesk();Say("実況係が動けない。Tabで別の組員へ");return;
        }
        if(!stageDeskAnnounced && (Flat(stageDeskRunner.Position,StageDeskPost)>.08f ||
            Mathf.Abs(stageDeskRunner.Position.y-StageDeskPost.y)>.25f)){
            MovePerson(stageDeskRunner,StageDeskPost,3.1f,dt);return;
        }
        Face(stageDeskRunner,StageDeskCentre);
        if(!stageDeskAnnounced){
            stageDeskAnnounced=true;stageLevelStarted=clock;
            Say(stageDeskRunner.name+"「実況卓についた。音を上げるで」");sound.Cue("dial");Mark("stage-desk-seated");
        }
        float elapsed=clock-stageLevelStarted;
        if(elapsed>1.85f){Motion(stageDeskRunner,"idle");return;}
        if(elapsed>=StageLevelSet && elapsed-dt<StageLevelSet)Mark("stage-desk-ready");
        float turn=Mathf.SmoothStep(0,1,Mathf.InverseLerp(.65f,StageLevelSet,elapsed));
        float grasp=Mathf.SmoothStep(0,1,elapsed/.54f)*(1-Mathf.SmoothStep(0,1,(elapsed-1.34f)/.48f));
        club.SetStageLevel(turn);
        club.StageLevelGrip(out var point,out var normal,out var fingers);
        stageDeskRunner.actor.SetStageLevelGrip(point,normal,fingers,grasp);
        Motion(stageDeskRunner,"stage-level");
    }

    float SpeakerSide=>boss.Position.x>=player.Position.x?1:-1;

    string StageBroadcastObjective()
    {
        if(stageBeat==StageBeat.Settled)return "立会人が勝負の決着を見届ける";
        if(StageSpeaking)return "金星から町の客へ、兄貴分の言葉を届ける";
        if(!stageReturned)return "白い輪で返す。Tabで実況係も出せる";
        if(!StageDeskReady){
            if(stageDeskRunner==null)return "勝負を続けるか、Tabで実況係を出す";
            return stageDeskAnnounced?"実況係が送出音量を調整中":"実況係が卓へ移動中。勝負も続けられる";
        }
        return "勝負を続けるか、マイクの"+(SpeakerSide>0?"左":"右")+"から E で中継";
    }

    string StageMicVerb()
    {
        if(!stageReturned || !StageDeskReady || StageSpeaking || stageBeat==StageBeat.Settled ||
            player.hp<=0 || boss.hp<=0 || (player.Position.x-StageMicrophone.x)*SpeakerSide>-.58f ||
            Flat(player.Position,StageMicrophone)>1.02f)return "";
        return AirStageWords;
    }

    void BeginTestimony()
    {
        speakerMark=StageMicrophone+new Vector3(.39f*SpeakerSide,0,.16f);
        Face(player,StageMicrophone);Motion(player,"idle");
        stageBeat=StageBeat.ToMicrophone;snapCamera=true;
        if(stageRing)stageRing.enabled=false;
        ShowStageLight(StageAmber,.7f,false);
        Say("真壁「町のみんなが聞いてる。ここで話してくれ」",2.5f);
        Mark("stage-mic-open");
    }

    void StageBroadcastShot(out Vector3 eye,out Vector3 focus)
    {
        float side=speakerMark.x>StageMicrophone.x?1:-1;
        eye=StageMicrophone+new Vector3(-side*.38f,1.49f,-1.85f);
        focus=Vector3.Lerp(StageMicrophone+Vector3.up*1.32f,boss.actor.EyePosition,.66f);
    }

    void TickTestimony(float dt)
    {
        if(!StageDeskReady){
            ClearStageDesk();StartStageBeat(StageBeat.Approach,1.1f,StageRest,false);return;
        }
        if(stageBeat==StageBeat.ToMicrophone){
            var before=boss.Position;
            var next=StageStep(before,Vector3.MoveTowards(before,speakerMark,1.5f*dt),player.Position);
            boss.root.position=next;
            if(Flat(next,speakerMark)>.025f){
                Face(boss,speakerMark);Motion(boss,"walk",1.5f);return;
            }
            Face(boss,StageMicrophone);Face(player,boss.Position);
            var capsule=StageMicrophone+Vector3.up*1.518f;
            boss.actor.SetConversationTargets(player.actor.EyePosition,capsule);
            boss.actor.SetAttentionTarget(capsule);Motion(boss,"stage-testimony");boss.flinchUntil=0;
            stageBeat=StageBeat.Testimony;stageBeatEnds=clock+4.8f;nextStageFrame=clock;
            stageFeedLive=true;club.SetStageBroadcast(true);sound.PlayStageTestimony();
            Say("兄貴分「金星を取ったんは、わしや。幕を返す。」",4.8f);
            Mark("stage-testimony-live");
        }
        if(clock>=nextStageFrame && SystemInfo.graphicsDeviceType!=UnityEngine.Rendering.GraphicsDeviceType.Null){
            nextStageFrame=clock+.12f;
            StageBroadcastShot(out var eye,out var focus);
            relayCam.transform.position=eye;relayCam.transform.LookAt(focus);
            relayCam.Render();club.SetExchangePicture(relayImage);club.SetStageMonitor(relayImage);
        }
        if(clock>=stageBeatEnds)
            End("stage-broadcast","金星から町内へ","兄貴分は町の客に舞台を託した。声を聞いた座長が、次の興行の前売りを約束した。");
    }
}
