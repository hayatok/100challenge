using UnityEngine;

public sealed partial class KinseiActor
{
    Vector3 stageLeftTip, stageRightTip;
    bool stageTipsReady;

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
