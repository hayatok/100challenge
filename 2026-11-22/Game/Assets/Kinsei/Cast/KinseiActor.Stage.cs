using UnityEngine;

public sealed partial class KinseiActor
{
    Vector3 stageLeftTip, stageRightTip;
    bool stageTipsReady;

    static byte[] testimonyMouth;
    static bool testimonyTrackLoaded;

    static float Phrase(float t,float begin,float peak,float hold,float end) =>
        Ease(begin,peak,t)*(1-Ease(hold,end,t));

    static Vector2 TestimonyMouthAt(byte[] frames,float t)
    {
        if(frames==null || frames.Length<2 || frames.Length%2!=0 || t<0)return Vector2.zero;
        int count=frames.Length/2;
        float frame=t*60;
        if(frame>=count)return Vector2.zero;
        int i=(int)frame,j=Mathf.Min(count-1,i+1);
        return new Vector2(Mathf.Lerp(frames[i*2],frames[j*2],frame-i),
            Mathf.Lerp(frames[i*2+1],frames[j*2+1],frame-i))/255f;
    }

    void PoseTestimonyBody(float t)
    {
        float inhale=Phrase(t,0,.24f,.27f,.67f);
        float settle=Phrase(t,.30f,.96f,3.16f,4.18f);
        float own=Phrase(t,1.63f,2.04f,2.33f,2.83f);
        float handover=Phrase(t,2.65f,3.12f,3.57f,4.30f);
        body.localPosition+=V(-.024f*settle+.030f*handover,-.025f*settle,.028f*settle);
        chest.localRotation=Quaternion.Euler(-2.3f*inhale+4.2f*settle,-8*own+6*handover,-2.7f*settle);
        la.localPosition+=Vector3.up*(.009f*inhale-.009f*settle);
        ra.localPosition+=Vector3.up*(.012f*inhale-.012f*settle);
        PlantGuardFoot(ll,lk,leftShoe,-1,-1);PlantGuardFoot(rl,rk,rightShoe,1,-1);
    }

    void PoseTestimonyHands(float t,out float leftCurl,out float rightCurl)
    {
        float confess=Phrase(t,1.59f,2.04f,2.35f,2.84f);
        float offer=Phrase(t,2.55f,3.10f,3.60f,4.43f);
        float unguard=Phrase(t,.13f,.63f,3.82f,4.56f);
        var wrist=Vector3.Lerp(V(.236f,.97f,.122f),V(.083f,1.32f,.187f),confess);
        wrist=Vector3.Lerp(wrist,V(.235f,1.145f,.365f),offer);
        var normal=Vector3.Lerp(V(-.66f,.27f,.35f),V(-.3f,.12f,-1),confess);
        normal=Vector3.Lerp(normal,V(-.18f,.91f,.32f),offer).normalized;
        var fingers=Vector3.Lerp(V(.07f,-.82f,.36f),V(-.58f,.78f,-.15f),confess);
        fingers=Vector3.ProjectOnPlane(Vector3.Lerp(fingers,V(-.20f,-.03f,.98f),offer),normal).normalized;
        ReachPalm(ra,re,rh,transform.TransformPoint(wrist),transform.TransformDirection(normal),
            transform.TransformDirection(fingers),unguard,transform.right);
        leftCurl=Mathf.Lerp(.32f,.17f,unguard);
        rightCurl=Mathf.Lerp(.44f,.07f,unguard)+.16f*confess;
    }

    void PoseTestimonyFace(float t)
    {
        if(!testimonyTrackLoaded){
            var track=Resources.Load<TextAsset>("KinseiAudio/stage-testimony-mouth");
            testimonyMouth=track?track.bytes:null;testimonyTrackLoaded=true;
        }
        var lips=TestimonyMouthAt(testimonyMouth,t);
        var mic=hasAttentionTarget?attentionEyes:EyePosition+transform.forward*.46f;
        var listener=hasConversationTargets?conversationEyes:mic+transform.forward*.85f;
        float meet=Ease(.90f,1.64f,t);
        var audience=EyePosition+Vector3.back*2.6f+transform.forward*1.2f;
        var gaze=Vector3.Lerp(Vector3.Lerp(mic,listener,meet),audience,Ease(2.46f,3.22f,t)*.66f);
        float blink=Mathf.Max(Phrase(t,.19f,.24f,.26f,.35f),Phrase(t,2.53f,2.58f,2.60f,2.71f));
        PerformCounterLine(gaze,.91f,lips.x,lips.y,blink);
    }

    internal void SingAtStand(Vector3 stand, float songSeconds, float amount)
    {
        float beats=songSeconds*76f/60f;
        float phrase=Mathf.Repeat(beats,6f)/6f;
        float breath=Mathf.Sin(phrase*2*Mathf.PI);
        float voice=Mathf.SmoothStep(0,1,Mathf.Clamp01(phrase*12))*
            (1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.76f,.97f,phrase)));
        chest.localRotation=Quaternion.Slerp(chest.localRotation,Quaternion.Euler(-breath*1.5f,0,breath*.8f),amount);
        head.localRotation=Quaternion.Slerp(head.localRotation,Quaternion.Euler(-voice*3,Mathf.Sin(beats*.47f)*4,0),amount);
        if(detailJaw)detailJaw.localRotation=Quaternion.Euler((3+4*Mathf.Abs(Mathf.Sin(beats*4.6f)))*voice*amount,0,0);
        ReachPalm(ra,re,rh,stand,transform.right,transform.up*.35f+transform.forward,amount,transform.right);
        if(rightHandRenderer)rightHandRenderer.SetBlendShapeWeight(0,Mathf.Lerp(34,65,amount));
        var left=transform.TransformPoint(new Vector3(-.17f,1.06f+breath*.021f,.23f));
        ReachPalm(la,le,lh,left,-transform.right,transform.up*.22f+transform.forward,amount,-transform.right);
    }

    internal void BeginSeated()
    {
        body.localPosition=rests[body]+V(-.021f,-.412f,-.012f);
        body.localRotation=Quaternion.Euler(0,7,-2);
        ll.localRotation=Quaternion.Euler(-85,0,-7);rl.localRotation=Quaternion.Euler(-92,0,8);
        lk.localRotation=Quaternion.Euler(79,0,1);rk.localRotation=Quaternion.Euler(94,0,-1);
        leftShoe.localRotation=Quaternion.Euler(6,-5,0);rightShoe.localRotation=Quaternion.Euler(-2,6,0);
    }

    internal void PlayKeys(Vector3 leftKey, Vector3 rightKey, float songSeconds,float amount)
    {
        if(!stageTipsReady)
        {
            stageLeftTip=CurvedFingertip(leftHandRenderer);
            stageRightTip=CurvedFingertip(rightHandRenderer);
            stageTipsReady=true;
        }
        float beat=songSeconds*76f/60f;
        chest.localRotation=Quaternion.Slerp(chest.localRotation,Quaternion.Euler(8+Mathf.Cos(beat*2*Mathf.PI)*.8f,-5,0),amount);
        AimHead((leftKey+rightKey)*.5f,amount*.78f);
        if(leftHandRenderer)leftHandRenderer.SetBlendShapeWeight(0,28);
        if(rightHandRenderer)rightHandRenderer.SetBlendShapeWeight(0,28);
        ReachPalm(la,le,lh,leftKey,-transform.up,transform.forward,amount,-transform.right,stageLeftTip);
        ReachPalm(ra,re,rh,rightKey,-transform.up,transform.forward,amount,transform.right,stageRightTip);
    }

    // The longest flexed digit is measured on the actual imported hand, including its mirrored rest fit.
    static Vector3 CurvedFingertip(SkinnedMeshRenderer hand)
    {
        if(!hand || !hand.sharedMesh)return new Vector3(0,-.137f,.006f);
        Mesh mesh=hand.sharedMesh;
        Vector3[] vertices=mesh.vertices,delta=new Vector3[vertices.Length];
        mesh.GetBlendShapeFrameVertices(0,0,delta,null,null);
        Vector3 longest=vertices[0]+delta[0]*.28f;
        for(int i=1;i<vertices.Length;i++)
        {
            Vector3 point=vertices[i]+delta[i]*.28f;
            if(point.y<longest.y)longest=point;
        }
        return longest;
    }
}
