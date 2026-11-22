using UnityEngine;

public sealed partial class KinseiActor
{
    int speechOpen=-1,speechRound=-1;

    // The imported mesh is already cloned per actor.
    public void PrepareCounterFace(int shop)
    {
        PrepareSpeechFace(shop==1?.03837f:shop==0?.0484f:.0483f);
    }

    void PrepareSpeechFace(float seam)
    {
        if(!faceRenderer || speechOpen>=0)return;
        var mesh=faceRenderer.sharedMesh;
        var points=mesh.vertices;
        var open=new Vector3[points.Length];var round=new Vector3[points.Length];
        for(int i=0;i<points.Length;i++){
            var p=points[i];
            LipOffsets(p,seam,out open[i],out round[i]);
        }
        speechOpen=mesh.blendShapeCount;mesh.AddBlendShapeFrame("Conversational lip opening",100,open,null,null);
        speechRound=mesh.blendShapeCount;mesh.AddBlendShapeFrame("Rounded lip corners",100,round,null,null);
    }

    static void LipOffsets(Vector3 p,float seam,out Vector3 open,out Vector3 round)
    {
        float h=p.y-seam;
        float centre=1-Ease(.010f,.030f,Mathf.Abs(p.x));
        float band=1-Ease(.005f,.017f,Mathf.Abs(h));
        float mask=centre*band*Ease(.082f,.100f,p.z);
        float lower=1-Ease(-.00065f,.00065f,h);
        open=V(0,Mathf.Lerp(.0013f,-.0046f,lower)*mask,-.0007f*lower*mask);
        float corner=1-Ease(.022f,.033f,Mathf.Abs(p.x));
        float roundMask=corner*band*Ease(.082f,.102f,p.z);
        round=V(-p.x*.095f*roundMask,0,.0026f*roundMask);
    }

    public void PerformCounterLine(Vector3 listener,float attention,float opening,float rounding,float blink)
    {
        AimHead(listener,attention*.87f);
        if(detailJaw)detailJaw.localRotation=Quaternion.Euler(opening*2.8f,0,0);
        if(speechOpen<0)return;
        faceRenderer.SetBlendShapeWeight(speechOpen,opening*100);
        faceRenderer.SetBlendShapeWeight(speechRound,rounding*100);
        float closure=Mathf.Max(blink,faceRenderer.GetBlendShapeWeight(0)*.01f);
        faceRenderer.SetBlendShapeWeight(0,closure*100);
        for(int i=0;i<eyes.Length;i++){
            var socket=eyes[i];
            Vector3 dir=head.InverseTransformDirection(listener-socket.position);
            float yaw=Mathf.Clamp(Mathf.Atan2(dir.x,dir.z)*Mathf.Rad2Deg,-14,14);
            float pitch=Mathf.Clamp(-Mathf.Atan2(dir.y,new Vector2(dir.x,dir.z).magnitude)*Mathf.Rad2Deg,-9,9);
            float rest=i==0?-7:7;
            socket.localRotation=Quaternion.Euler(pitch*attention,rest+yaw*attention,0);
            socket.localScale=V(1,Mathf.Lerp(1,.19f,closure),Mathf.Lerp(1,.82f,closure));
        }
    }

    public void ReleaseCounterLine()
    {
        if(speechOpen<0)return;
        faceRenderer.SetBlendShapeWeight(speechOpen,0);faceRenderer.SetBlendShapeWeight(speechRound,0);
        if(detailJaw)detailJaw.localRotation=Quaternion.identity;
        for(int i=0;i<eyes.Length;i++)eyes[i].localRotation=Quaternion.Euler(0,i==0?-7:7,0);
    }
}
