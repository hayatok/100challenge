using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

public sealed partial class KinseiSession
{
    KinseiActor portraitOwner;
    Person yieldingPortrait;
    static readonly float[] PortraitAngles={0,20,-20,38,-38,58,-58,78,-78};
    readonly RaycastHit[] portraitWalls=new RaycastHit[24];
    float hallPortraitAngle,portraitCheckAt;
    readonly List<(Renderer part,ShadowCastingMode shadows)> portraitForeground=new();

    bool LookingAroundHall=>!command && !finale && (phase==Phase.Floor || phase==Phase.Choice || phase==Phase.Chase);

    Person NearbyYieldingGuard()
    {
        if(!LookingAroundHall)return null;
        Person nearest=null;float best=2.6f;
        foreach(var guard in guards){
            float d=Vector3.Distance(guard.Position,player.Position);
            if(guard.floorYielded && d<best && ClearBetween(player,guard)){best=d;nearest=guard;}
        }
        return nearest;
    }

    void HallPortraitInput()
    {
        bool moving=Input.GetAxisRaw("Horizontal")!=0 || Input.GetAxisRaw("Vertical")!=0;
        bool acting=Input.GetMouseButton(1) || Input.GetMouseButton(0) || Input.GetKeyDown(KeyCode.Q) ||
            Input.GetKeyDown(KeyCode.E) || Input.GetKeyDown(KeyCode.F) || Input.GetKeyDown(KeyCode.Space);
        if(yieldingPortrait!=null){
            if(!Input.GetKey(KeyCode.Z) || moving || acting || !LookingAroundHall ||
                Vector3.Distance(yieldingPortrait.Position,player.Position)>2.6f || !ClearBetween(player,yieldingPortrait)){
                yieldingPortrait=null;snapCamera=true;SetCamera(0);
            }
        } else if(Input.GetKeyDown(KeyCode.Z) && !moving && !acting){
            yieldingPortrait=NearbyYieldingGuard();
            if(yieldingPortrait!=null){
                hallPortraitAngle=0;portraitCheckAt=0;
                snapCamera=true;Mark("look-yield-"+GuardName(yieldingPortrait));
            }
        }
    }

    void FrameYieldingGuard(out Vector3 eye,out Vector3 focus)
    {
        focus=yieldingPortrait.Position+Vector3.up*.63f;
        if(clock>=portraitCheckAt){
            bool first=portraitCheckAt==0;
            portraitCheckAt=clock+.32f;
            float previous=hallPortraitAngle;
            float best=float.PositiveInfinity;
            foreach(float angleOption in PortraitAngles){
                var candidate=PortraitCameraPoint(focus,angleOption);
                float cost=Mathf.Abs(angleOption)*.075f+Mathf.Max(0,1.96f-Vector3.Distance(candidate,focus))*85;
                if(angleOption!=previous && !snapCamera)cost+=1.3f;
                foreach(var other in everyone){
                    if(other==yieldingPortrait || !other.root.gameObject.activeInHierarchy ||
                        (other.Position-focus).sqrMagnitude>11)continue;
                    cost+=Mathf.Min(1.2f,PortraitObstruction(candidate,yieldingPortrait.actor.EyePosition,other));
                    cost+=Mathf.Min(.7f,PortraitObstruction(candidate,yieldingPortrait.actor.LeftWrist.position,other));
                    cost+=Mathf.Min(.6f,PortraitObstruction(candidate,focus,other));
                }
                if(cost<best){best=cost;hallPortraitAngle=angleOption;}
            }
            if(previous!=hallPortraitAngle)snapCamera=true;
            if(measure && (first || previous!=hallPortraitAngle)){
                var cameraAt=PortraitCameraPoint(focus,hallPortraitAngle);
                Debug.Log($"KINSEI_PORTRAIT {GuardName(yieldingPortrait)} angle={hallPortraitAngle:F0} distance={Vector3.Distance(focus,cameraAt):F2}m");
            }
        }
        eye=PortraitCameraPoint(focus,hallPortraitAngle);
    }

    Vector3 PortraitCameraPoint(Vector3 focus,float angleOption)
    {
        var offset=Quaternion.AngleAxis(angleOption,Vector3.up)*yieldingPortrait.root.forward*2.04f+Vector3.up*.30f;
        float reach=offset.magnitude;
        int n=Physics.SphereCastNonAlloc(focus,.075f,offset.normalized,portraitWalls,reach,~0,QueryTriggerInteraction.Ignore);
        for(int i=0;i<n;i++)
            if(portraitWalls[i].collider!=motor)reach=Mathf.Min(reach,Mathf.Max(.22f,portraitWalls[i].distance-.08f));
        return focus+offset.normalized*reach;
    }

    // A sleeve can cross the line to the eyes while both actors' roots are clear of the lens.
    static float PortraitObstruction(Vector3 eye,Vector3 detail,Person other)
    {
        Vector3 ray=eye-detail;ray.y=0;
        Vector3 offset=other.Position-detail;offset.y=0;
        float along=Vector3.Dot(offset,ray)/Mathf.Max(.001f,ray.sqrMagnitude);
        if(along<-.04f || along>1.11f)return 0;
        var near=Vector3.Lerp(detail,eye,Mathf.Clamp01(along));
        if(near.y>other.actor.EyePosition.y+.19f || near.y<other.Position.y-.05f)return 0;
        float distance=(offset-ray*along).magnitude;
        return Mathf.Max(0,.63f-distance)*18;
    }

    void ClearPortraitForeground(Camera view)
    {
        if(view!=cam || yieldingPortrait==null || !LookingAroundHall)return;
        Vector3 eye=view.transform.position, face=yieldingPortrait.actor.EyePosition;
        foreach(var other in everyone){
            if(other==yieldingPortrait || !other.root.gameObject.activeInHierarchy || (other.Position-face).sqrMagnitude>11)continue;
            // Keep the person's shadow and simulation. Only the close camera looks through a blocking figure.
            if(PortraitObstruction(eye,face,other)<.6f && PortraitObstruction(eye,yieldingPortrait.actor.LeftWrist.position,other)<.9f &&
                PortraitObstruction(eye,yieldingPortrait.Position+Vector3.up*.51f,other)<1.2f)continue;
            other.portraitRenderers??=other.root.GetComponentsInChildren<Renderer>(true);
            foreach(var part in other.portraitRenderers){
                if(!part || !part.enabled || !part.gameObject.activeInHierarchy || part.shadowCastingMode==ShadowCastingMode.ShadowsOnly)continue;
                portraitForeground.Add((part,part.shadowCastingMode));part.shadowCastingMode=ShadowCastingMode.ShadowsOnly;
            }
        }
    }

    void RestorePortraitForeground(Camera view)
    {
        if(view!=cam)return;
        foreach(var restored in portraitForeground)if(restored.part)restored.part.shadowCastingMode=restored.shadows;
        portraitForeground.Clear();
    }

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
    string PortraitHint => shopView!=ShopView.None ? "" :
        portraitOwner?"Z　元の視点へ":neighbours.SpeakingOwner?"Z　話す相手を見る":"";
}
