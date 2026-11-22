using UnityEngine;

public sealed partial class KinseiActor
{
    Vector3 stageLevelPoint,stageLevelNormal,stageLevelFingers;
    float stageLevelReach;

    public void SetStageLevelGrip(Vector3 point,Vector3 normal,Vector3 fingers,float reach)
    {
        stageLevelPoint=point;stageLevelNormal=normal;stageLevelFingers=fingers;stageLevelReach=reach;
        if(leftHandRenderer && leftTicketShape<0){
            var mesh=leftHandRenderer.sharedMesh;
            leftTicketShape=mesh.blendShapeCount;
            AddTicketPinch(mesh,true);
        }
    }

    void PoseStageLevelHand()
    {
        AimHead(stageLevelPoint,.78f*stageLevelReach);
        ReachPalm(la,le,lh,stageLevelPoint,stageLevelNormal,stageLevelFingers,
            stageLevelReach,-transform.right,TicketPinch);
        if(leftHandRenderer && leftTicketShape>=0){
            leftHandRenderer.SetBlendShapeWeight(0,0);
            leftHandRenderer.SetBlendShapeWeight(leftTicketShape,100*stageLevelReach);
        }
    }

    void PoseStageAudienceBody(string pose,float elapsed)
    {
        if(pose=="stage-level"){
            // Lean from the hips over the control. The foot roots stay at the arrived mark.
            chest.localRotation=Quaternion.Euler(25*stageLevelReach,0,0);
            return;
        }
        if(pose!="audience-turn" && pose!="audience-signal" && pose!="audience-clap")return;
        float weight=Ease(0,.35f,elapsed);
        bool left=pose=="audience-turn";
        float side=left?-1:1;
        body.localPosition+=V(side*.018f,-.018f,.005f)*weight;
        chest.localRotation=Quaternion.Euler(4*weight,side*(left?20:8)*weight,-side*4*weight);
        head.localRotation=Quaternion.Euler(-3*weight,side*(left?22:5)*weight,0);
        if(pose=="audience-signal"){
            var palm=transform.TransformPoint(V(.26f,1.40f,.28f));
            ReachPalm(ra,re,rh,palm,transform.forward,transform.up,weight,transform.right);
        }
        if(pose=="audience-clap"){
            float spread=.011f+.094f*(.5f+.5f*Mathf.Cos((elapsed-.38f)*Mathf.PI*3.3f));
            var centre=transform.TransformPoint(V(-.022f,1.27f,.30f));
            ReachPalm(la,le,lh,centre-transform.right*spread,transform.right,transform.up,weight,-transform.right);
            ReachPalm(ra,re,rh,centre+transform.right*spread,-transform.right,transform.up,weight,transform.right);
        }
    }
}
