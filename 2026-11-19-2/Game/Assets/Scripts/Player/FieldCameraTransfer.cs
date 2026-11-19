using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        const float TransferSeconds=.56f;
        bool blendingView;
        float blendElapsed;
        Vector3 blendOrigin,blendPawn;
        Quaternion blendRotation;
        Matrix4x4 blendProjection;
        int blendPawnId;

        void BeginViewTransfer(Unit pawn,bool entering)
        {
            if(pawn==null || ReducedMotion){EndViewTransfer();return;}
            var t=eye.transform;
            blendOrigin=t.position;blendRotation=t.rotation;blendPawn=pawn.pos+Vector3.up*1.52f;
            bool continuing=blendingView;
            blendProjection=eye.projectionMatrix;
            if(!continuing && !eye.orthographic)
                for(int i=0;i<16;i++)blendProjection[i]/=49;
            if(entering && (Vector3.ProjectOnPlane(blendOrigin-blendPawn,Vector3.up)).sqrMagnitude>60*60)
                blendOrigin=blendPawn+Vector3.up*11-blendRotation*Vector3.forward*14;
            blendElapsed=0;blendPawnId=pawn.id;blendingView=true;
        }

        void EndViewTransfer()
        {
            if(!blendingView)return;
            blendingView=false;eye.ResetProjectionMatrix();
        }

        void BlendView(float dt,bool entering)
        {
            if(!blendingView)return;
            blendElapsed+=dt;
            if(ReducedMotion || blendElapsed>=TransferSeconds){EndViewTransfer();return;}
            float t=Mathf.SmoothStep(0,1,blendElapsed/TransferSeconds);
            var cameraTransform=eye.transform;
            Vector3 finish=cameraTransform.position;
            Quaternion finalRotation=cameraTransform.rotation;
            var startControl=entering?Vector3.Lerp(blendOrigin,finish,.38f)+Vector3.up*5:blendOrigin+Vector3.up*4.3f;
            var endControl=entering?finish+Vector3.up*4.3f:Vector3.Lerp(blendOrigin,finish,.62f)+Vector3.up*5;
            float rest=1-t;
            Vector3 point=rest*rest*rest*blendOrigin+3*rest*rest*t*startControl+3*rest*t*t*endControl+t*t*t*finish;
            var rotation=Quaternion.Slerp(blendRotation,finalRotation,t);
            var focus=entering?finish:blendPawn;
            var direction=focus-point;
            if(direction.sqrMagnitude>2.5f)
            {
                float hold=Mathf.Sin(t*Mathf.PI)*.75f;
                var heading=Quaternion.LookRotation(direction,rotation*Vector3.up);
                rotation=Quaternion.Slerp(rotation,heading,hold);
            }
            cameraTransform.SetPositionAndRotation(point,rotation);
            // At the map focus distance both projections have the same homogeneous w.
            // This preserves apparent scale while changing between parallel and perspective rays.
            float zNear=eye.nearClipPlane,zFar=eye.farClipPlane;
            float half=eye.orthographicSize,wide=half*eye.aspect;
            var target=entering?Matrix4x4.Perspective(eye.fieldOfView,eye.aspect,zNear,zFar):
                Matrix4x4.Ortho(-wide,wide,-half,half,zNear,zFar);
            var projection=new Matrix4x4();
            for(int i=0;i<16;i++)projection[i]=Mathf.Lerp(blendProjection[i],entering?target[i]/49:target[i],t);
            eye.projectionMatrix=projection;
        }

        bool InBodyView(Unit actor)
        {
            if(!blendingView)return actor==sim.Controlled;
            return actor.id==blendPawnId && (eye.transform.position-actor.pos-Vector3.up*1.52f).sqrMagnitude<.95f;
        }

        void FinishTransferForInput()
        {
            if(!blendingView)return;
            EndViewTransfer();FrameCamera(0,true);
        }
    }
}
