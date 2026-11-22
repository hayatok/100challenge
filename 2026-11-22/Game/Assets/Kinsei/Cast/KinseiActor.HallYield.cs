using UnityEngine;

public sealed partial class KinseiActor
{
    Vector3 yieldLeftStart,yieldRightStart;
    Quaternion yieldLeftShoe,yieldRightShoe;
    static readonly Vector3 YieldPalmPad=V(0,-.077f,.013f);
    Vector3 yieldPalmStart,yieldElbowStart;
    Quaternion yieldWristStart;
    byte[] hallMouth;

    void PoseHallYieldFace(float seconds)
    {
        var lips=TestimonyMouthAt(hallMouth,seconds);
        var target=hasAttentionTarget?attentionEyes:EyePosition+transform.forward*2;
        PerformCounterLine(target,.6f,lips.x,lips.y,Phrase(seconds,.16f,.22f,.28f,.38f));
    }

    void BeginHallYield()
    {
        yieldPalmStart=transform.InverseTransformPoint(rh.TransformPoint(YieldPalmPad));
        yieldWristStart=Quaternion.Inverse(transform.rotation)*rh.rotation;
        yieldElbowStart=transform.InverseTransformDirection((re.position-ra.position).normalized);
        yieldLeftStart=transform.InverseTransformPoint(leftShoe.position);
        yieldRightStart=transform.InverseTransformPoint(rightShoe.position);
        yieldLeftShoe=Quaternion.Inverse(transform.rotation)*leftShoe.rotation;
        yieldRightShoe=Quaternion.Inverse(transform.rotation)*rightShoe.rotation;
    }

    void PoseHallYieldBody(float seconds)
    {
        float brace=Ease(0,.17f,seconds);
        float lower=Ease(.23f,.89f,seconds);
        float settle=Ease(.80f,1.20f,seconds);
        body.localPosition=V(-.022f*lower,.96f-.052f*brace-.486f*lower+.005f*settle,.054f*lower);
        chest.localRotation=Quaternion.Euler(12*brace+7*lower-10*settle,-9*brace,4*lower);
        head.localRotation=Quaternion.Euler(12*brace-18*settle,-7+5*settle,-3*lower);
        if(hasAttentionTarget)AimHead(attentionEyes,.53f*settle);
    }

    void PoseHallYieldLimbs(float seconds,out float leftCurl,out float rightCurl)
    {
        // One short step brings the right shoe ahead even when the call interrupts mid-stride.
        float step=Ease(0,.42f,seconds);
        float drop=Ease(.23f,.89f,seconds);
        float lift=Ease(.06f,.78f,seconds);
        var rightFloor=V(.13f,0,Mathf.Max(.20f,yieldRightStart.z));
        var rightAt=Vector3.Lerp(yieldRightStart,rightFloor,step);
        var leftAt=Vector3.Lerp(yieldLeftStart,V(-.148f,0,-.207f),drop);
        var rightRotation=Quaternion.Slerp(yieldRightShoe,Quaternion.Euler(0,8,0),step);
        var leftRotation=Quaternion.Slerp(yieldLeftShoe,Quaternion.Euler(38,-9,0),drop);
        float reach=Mathf.Min(.085f,Vector2.Distance(new Vector2(yieldRightStart.x,yieldRightStart.z),
            new Vector2(rightFloor.x,rightFloor.z))*.22f);
        rightAt.y=ShoeClearance(rightRotation)+(1-step)*Mathf.Max(0,yieldRightStart.y-ShoeClearance(yieldRightShoe))+reach*Mathf.Sin(step*Mathf.PI);
        leftAt.y=ShoeClearance(leftRotation)+(1-drop)*Mathf.Max(0,yieldLeftStart.y-ShoeClearance(yieldLeftShoe))+.032f*Mathf.Sin(drop*Mathf.PI);
        SolveLimb(rl,rk,rightShoe,transform.TransformPoint(rightAt),transform.forward,1);
        SolveLimb(ll,lk,leftShoe,transform.TransformPoint(leftAt),transform.forward,1);
        rightShoe.rotation=transform.rotation*rightRotation;
        leftShoe.rotation=transform.rotation*leftRotation;

        var openPalm=chest.TransformPoint(V(-.30f,.38f,.125f));
        ReachPalm(la,le,lh,openPalm,transform.forward,transform.up,lift,-transform.right);
        // Rest the palm across the top of the trouser leg, leaving the fingers over the front.
        var bracePoint=rk.TransformPoint(V(.012f,.018f,.063f))+transform.up*.0605f-transform.forward*.090f;
        // Lead the hand outside the rising thigh, then lower the palm onto the wool.
        float place=Ease(0,1.12f,seconds);
        var control=transform.TransformPoint(V(.40f,1.06f,.30f));
        var from=Vector3.Lerp(transform.TransformPoint(yieldPalmStart),control,place);
        var toward=Vector3.Lerp(control,bracePoint,place);
        var palm=Vector3.Lerp(from,toward,place);
        var wrist=Quaternion.Slerp(transform.rotation*yieldWristStart,
            Quaternion.LookRotation(-transform.up,-transform.forward),place);
        var elbow=Vector3.Slerp(transform.TransformDirection(yieldElbowStart),
            (-transform.up+transform.right*.44f).normalized,place);
        SolveLimb(ra,re,rh,palm-wrist*YieldPalmPad,elbow,1);
        rh.rotation=wrist;
        leftCurl=Mathf.Lerp(.48f,.035f,lift);
        rightCurl=Mathf.Lerp(.4f,.17f,drop);
    }

    static float ShoeClearance(Quaternion rotation)
    {
        // The lowest point can lie on the leather toe or on the sole as the heel lifts.
        var up=Quaternion.Inverse(rotation)*Vector3.up;
        float toe=Vector3.Scale(up,V(.055f,.050f,.122f)).magnitude-Vector3.Dot(up,V(0,-.017f,.054f));
        float sole=Vector3.Scale(up,V(.056f,.017f,.124f)).magnitude-Vector3.Dot(up,V(0,-.052f,.056f));
        return Mathf.Max(toe,sole);
    }
}
