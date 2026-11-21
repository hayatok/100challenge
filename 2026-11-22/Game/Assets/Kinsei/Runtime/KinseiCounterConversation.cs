using UnityEngine;

public sealed partial class KinseiSession
{
    KinseiActor portraitOwner;

    void SpeakAtCounter(int shop,string words,float seconds=3.4f)
    {
        Say(words,seconds);
        neighbours.BeginCounterLine(shop,words,clock,seconds,player.actor.EyePosition);
    }

    void PortraitInput()
    {
        if(command || finale && OnAir || AboveStreet || shopView!=ShopView.None ||
            (phase!=Phase.Arrival && !InDawn) || Input.GetKeyDown(KeyCode.C) ||
            Input.GetAxisRaw("Horizontal")!=0 || Input.GetAxisRaw("Vertical")!=0 ||
            (portraitOwner && (portraitOwner.EyePosition-player.actor.EyePosition).sqrMagnitude>11)){
            if(portraitOwner){portraitOwner=null;snapCamera=true;}
            return;
        }
        if(!Input.GetKeyDown(KeyCode.Z))return;
        if(portraitOwner)portraitOwner=null;
        else if(neighbours.SpeakingOwner)portraitOwner=neighbours.SpeakingOwner;
        else if(StreetContact(out int shop,out _))portraitOwner=neighbours.Owner(shop);
        snapCamera=true;
    }

    void FrameConversation(out Vector3 eye,out Vector3 focus)
    {
        Vector3 eyesAt=portraitOwner.EyePosition;
        Vector3 toward=player.actor.EyePosition-eyesAt;toward.y=0;
        if(toward.sqrMagnitude<.01f)toward=portraitOwner.transform.forward;
        toward.Normalize();Vector3 side=Vector3.Cross(Vector3.up,toward);
        focus=eyesAt-Vector3.up*.026f;
        Vector3 delta=toward*.69f+side*.15f+Vector3.up*.04f;
        eye=focus+delta;
        if(Physics.SphereCast(focus,.055f,delta.normalized,out var hit,delta.magnitude,~0,QueryTriggerInteraction.Ignore))
            eye=focus+delta.normalized*Mathf.Max(.10f,hit.distance-.035f);
    }
    string PortraitHint => portraitOwner?"Z　元の視点へ":neighbours.SpeakingOwner?"Z　話す相手を見る":"";
}
