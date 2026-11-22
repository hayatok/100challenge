using UnityEngine;

public sealed partial class KinseiSession
{
    bool legacyMouseControls;
    float lookSensitivity=1f, aimSensitivity=.45f;
    int shoulderReadyFrame;
    bool shoulderButtonsReleased=true;
    Vector3 shoulderHitPoint;
    readonly RaycastHit[] shoulderBarrierHits=new RaycastHit[16];
    Vector3 ShoulderScreenPoint => new Vector3(Screen.width*.5f,Screen.height*.49f,0);
    bool ShoulderView => Application.isFocused && !paused && player!=null && !command &&
        phase!=Phase.Title && phase!=Phase.Result && phase!=Phase.Mirror && !OnAir &&
        !pullingBackstage && !ticketActing && shopView==ShopView.None && !portraitOwner && yieldingPortrait==null &&
        !(StageActive && (StageSpeaking || stageBeat==StageBeat.Settled || player.hp<=0));
    bool ShoulderInputReady => Time.frameCount>shoulderReadyFrame && shoulderButtonsReleased && Application.isFocused;
    bool ShoulderAiming => !legacyMouseControls && ShoulderView && ShoulderInputReady &&
        !finale && !InDawn && !AboveStreet && !westDuel && !StageActive &&
        (phase==Phase.Floor || phase==Phase.Chase) && Input.GetMouseButton(1);

    bool ShoulderSightHasTarget
    {
        get {
            if(legacyMouseControls || !ShoulderView || (phase!=Phase.Floor && phase!=Phase.Chase))return false;
            Targets();return PickShoulderTarget()!=null;
        }
    }

    void LoadShoulderSettings()
    {
        legacyMouseControls=PlayerPrefs.GetInt("Kinsei.LegacyMouseControls",0)==1;
        lookSensitivity=ReadSensitivity("Kinsei.LookSensitivity",1f);
        aimSensitivity=ReadSensitivity("Kinsei.AimSensitivity",.45f);
    }
    static float ReadSensitivity(string key,float fallback)
    {
        float value=PlayerPrefs.GetFloat(key,fallback);
        return float.IsNaN(value) || float.IsInfinity(value)?fallback:Mathf.Clamp(value,.2f,2f);
    }
    void SaveShoulderSettings()
    {
        lookSensitivity=Mathf.Clamp(lookSensitivity,.2f,2f);
        aimSensitivity=Mathf.Clamp(aimSensitivity,.2f,2f);
        PlayerPrefs.SetInt("Kinsei.LegacyMouseControls",legacyMouseControls?1:0);
        PlayerPrefs.SetFloat("Kinsei.LookSensitivity",lookSensitivity);
        PlayerPrefs.SetFloat("Kinsei.AimSensitivity",aimSensitivity);
        PlayerPrefs.Save();
        ResetShoulderInput();
    }
    void ResetShoulderInput()
    {
        shoulderReadyFrame=Time.frameCount+1;
        shoulderButtonsReleased=false;
        RefreshShoulderCursor();
    }
    void RefreshShoulderCursor()
    {
        var wanted=ShoulderView && !legacyMouseControls?CursorLockMode.Locked:CursorLockMode.None;
        if(Cursor.lockState!=wanted){
            Cursor.lockState=wanted;
            shoulderReadyFrame=Time.frameCount+1;
            shoulderButtonsReleased=false;
        }
        Cursor.visible=wanted!=CursorLockMode.Locked;
        // A click that closed a menu or activated this window must never become a shot.
        if(!Input.GetMouseButton(0) && !Input.GetMouseButton(1) && !Input.GetKey(KeyCode.Space))
            shoulderButtonsReleased=true;
    }
    void ApplyShoulderLook()
    {
        if(!ShoulderView || !ShoulderInputReady)return;
        if(legacyMouseControls && !Input.GetMouseButton(1))return;
        float sensitivity=ShoulderAiming?aimSensitivity:lookSensitivity;
        angle+=Input.GetAxisRaw("Mouse X")*3.1f*sensitivity;
        tilt=Mathf.Clamp(tilt-Input.GetAxisRaw("Mouse Y")*2f*sensitivity,-32,43);
    }

    void AlignShoulderTarget(Vector3 target)
    {
        // Q is a one-time camera alignment. Solve against the actual shoulder camera,
        // including its shortened boom, height, FOV and the slightly lowered sight.
        // No target tracking persists once the player starts looking around again.
        for(int i=0;i<8;i++){
            SetCamera(0);
            Vector3 local=cam.transform.InverseTransformDirection(target-cam.transform.position);
            Vector3 sight=cam.transform.InverseTransformDirection(cam.ScreenPointToRay(ShoulderScreenPoint).direction);
            float yawError=Mathf.Atan2(local.x,local.z)-Mathf.Atan2(sight.x,sight.z);
            float pitchError=Mathf.Atan2(-local.y,new Vector2(local.x,local.z).magnitude)-
                Mathf.Atan2(-sight.y,new Vector2(sight.x,sight.z).magnitude);
            angle+=yawError*Mathf.Rad2Deg;
            tilt=Mathf.Clamp(tilt+pitchError*Mathf.Rad2Deg,-32,43);
            if(Mathf.Abs(yawError)+Mathf.Abs(pitchError)<.00005f)break;
        }
        SetCamera(0);
    }

    bool ShoulderBarrier(Ray ray,float length,out RaycastHit closest)
    {
        closest=default;
        bool found=false;
        // Ignore only the player's motor, continuing beyond it so a wall is never
        // bypassed when the first physics hit happened to be our own capsule.
        int count=Physics.RaycastNonAlloc(ray,shoulderBarrierHits,length,~0,QueryTriggerInteraction.Ignore);
        // NonAlloc does not guarantee which hits survive saturation. Only this rare
        // case allocates, preserving occlusion even through densely overlapping props.
        var hits=count==shoulderBarrierHits.Length?
            Physics.RaycastAll(ray,length,~0,QueryTriggerInteraction.Ignore):shoulderBarrierHits;
        if(hits!=shoulderBarrierHits)count=hits.Length;
        for(int i=0;i<count;i++){
            var hit=hits[i];
            if(hit.collider==motor || hit.distance>=length)continue;
            length=hit.distance;closest=hit;found=true;
        }
        return found;
    }

    static bool ShoulderCapsuleHit(Ray ray,Vector3 feet,out float distance)
    {
        // Vertical capsule: hip through crown, in the same world units as the cast.
        // Both the reticle and damage selection call this exact intersection.
        const float radius=.30f, bottom=.68f, top=1.52f;
        Vector3 origin=ray.origin-feet, direction=ray.direction;
        distance=float.PositiveInfinity;
        float a=direction.x*direction.x+direction.z*direction.z;
        float b=origin.x*direction.x+origin.z*direction.z;
        float c=origin.x*origin.x+origin.z*origin.z-radius*radius;
        if(a>.000001f){
            float discriminant=b*b-a*c;
            if(discriminant>=0){
                float root=Mathf.Sqrt(discriminant);
                CapsuleCylinderRoot((-b-root)/a,origin.y,direction.y,bottom,top,ref distance);
                CapsuleCylinderRoot((-b+root)/a,origin.y,direction.y,bottom,top,ref distance);
            }
        }
        CapsuleSphereRoot(origin-Vector3.up*bottom,direction,radius,ref distance);
        CapsuleSphereRoot(origin-Vector3.up*top,direction,radius,ref distance);
        return !float.IsPositiveInfinity(distance);
    }
    static void CapsuleCylinderRoot(float at,float originY,float directionY,float bottom,float top,ref float nearest)
    {
        float height=originY+directionY*at;
        if(at>=0 && at<nearest && height>=bottom && height<=top)nearest=at;
    }
    static void CapsuleSphereRoot(Vector3 origin,Vector3 direction,float radius,ref float nearest)
    {
        float along=Vector3.Dot(origin,direction);
        float discriminant=along*along-origin.sqrMagnitude+radius*radius;
        if(discriminant<0)return;
        float at=-along-Mathf.Sqrt(discriminant);
        if(at>=0 && at<nearest)nearest=at;
    }

    Person PickShoulderTarget()
    {
        // Actors have no physics colliders. Intersect the exact displayed sight ray with
        // their standing head-to-hip capsule, then check world obstruction and muzzle path.
        Ray ray=cam.ScreenPointToRay(ShoulderScreenPoint);
        shoulderHitPoint=ray.GetPoint(14);
        float nearest=18f;
        if(ShoulderBarrier(ray,nearest,out var wall)){
            nearest=wall.distance;shoulderHitPoint=wall.point;
        }
        Person best=null;
        foreach(var candidate in combatants){
            Vector3 center=candidate.Position+Vector3.up*1.15f;
            if(Vector3.Distance(player.Position+Vector3.up*1.38f,center)>13.5f)continue;
            if(!ShoulderCapsuleHit(ray,candidate.Position,out float distance) || distance>=nearest)continue;
            Vector3 hit=ray.GetPoint(distance);
            Vector3 muzzle=player.Position+Vector3.up*1.31f+player.root.right*.16f+player.root.forward*.43f;
            Vector3 path=hit-muzzle;
            if(ShoulderBarrier(new Ray(muzzle,path.normalized),path.magnitude,out _))continue;
            nearest=distance;best=candidate;shoulderHitPoint=hit;
        }
        return best;
    }
}
