using UnityEngine;

namespace Evac
{
    public sealed partial class WorldView
    {
        readonly string[] incidentForms={"Bell","Shutter","Lamp","Cart","Water","Points"};
        sealed class IncidentRig
        {
            public GameObject owner,root,working,projection;
            public MeshRenderer projected;
            public MaterialPropertyBlock properties;
            public int sector=-1;
        }
        readonly IncidentRig[] fieldRigs={new IncidentRig(),new IncidentRig()};
        Material incidentMaterial;
        Mesh incidentPatch;
        void PrepareIncidentPatch()
        {
            if(incidentMaterial)return;
            incidentMaterial=new Material(Resources.Load<Shader>("World/IncidentProjection"));
            incidentPatch=new Mesh{name="Local incident light and water"};
            incidentPatch.vertices=new[]{new Vector3(-1,0,0),new Vector3(1,0,0),new Vector3(1,0,1),new Vector3(-1,0,1)};
            incidentPatch.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};
            incidentPatch.triangles=new[]{0,1,2,2,3,0};incidentPatch.RecalculateBounds();incidentPatch.UploadMeshData(true);
        }
        internal void RenderIncident(GameSim sim)
        {
            for(int offset=0;offset<2;offset++){
                int sector=sim.Sector+offset;
                var display=fieldRigs[sector%2];
                if(district && sim.ShowFieldEvent(sector))UpdateIncidentRig(sim,sector,display);
                else if(display.root && display.root.activeSelf)display.root.SetActive(false);
            }
        }
        void UpdateIncidentRig(GameSim sim,int sector,IncidentRig display)
        {
            int kind=sim.FieldEventType(sector);
            if(display.owner!=district || display.sector!=sector || !display.root){
                if(display.root){display.root.SetActive(false);ReleaseOwned(display.root);}
                display.owner=district;display.sector=sector;
                string model="incident"+incidentForms[kind];
                display.root=MakeObject(model,GetMesh(model+"Base"),district.transform);
                display.working=MakeObject(model+" mechanism",GetMesh(model+"Moving"),display.root.transform);
                display.projection=null;
                if(kind==2 || kind==4){
                    PrepareIncidentPatch();
                    display.projection=MakeObject(model+" projection",incidentPatch,display.root.transform);
                    display.projected=display.projection.GetComponent<MeshRenderer>();
                    display.projected.sharedMaterial=incidentMaterial;
                    if(display.properties==null)display.properties=new MaterialPropertyBlock();
                    display.properties.SetFloat("_Water",kind==4?1:0);
                }
            }
            if(!display.root.activeSelf)display.root.SetActive(true);
            var position=sim.EventObjectPosition(sector);
            display.root.transform.localPosition=position;
            float action=sim.EventMechanism(sector),pressure=sim.EventPressure(sector),time=sim.Elapsed;
            var moving=display.working.transform;
            switch(kind){
                case 0: moving.localRotation=Quaternion.Euler(0,action*8*Mathf.Sin(time*5.7f),0);break;
                case 1: moving.localScale=new Vector3(1,Mathf.Lerp(1,.13f,action),1);
                    moving.localPosition=Vector3.up*action*2.19f;break;
                case 2: moving.localRotation=Quaternion.Euler(0,Mathf.Sin(time*.68f)*30*action,0);
                    display.projection.transform.localPosition=Vector3.up*.075f;
                    display.projection.transform.localRotation=Quaternion.Euler(0,180+Mathf.Sin(time*.68f)*30*action,0);
                    display.projection.transform.localScale=new Vector3(2.7f,1,6+action*5);break;
                case 3:
                    var next=sim.EventStarted(sector)?sim.EventCartPosition(sector):position+Vector3.back*1.15f;
                    var delta=next-moving.position;
                    if(sim.EventStarted(sector) && delta.sqrMagnitude>.002f)moving.rotation=Quaternion.LookRotation(delta.normalized,Vector3.up);
                    moving.position=next;break;
                case 4: moving.localRotation=Quaternion.Euler(0,action*52,0);
                    display.projection.transform.localPosition=new Vector3(0,.071f,-2.5f);
                    display.projection.transform.localScale=new Vector3(2.0f+2.4f*pressure,1,3.5f+2.9f*pressure);break;
                case 5: moving.localRotation=Quaternion.Euler(0,(sim.EventQuick(sector)?-1:1)*action*77,0);break;
            }
            if(display.projection){
                display.properties.SetFloat("_Strength",kind==4?pressure:action);
                display.properties.SetFloat("_Clock",time);
                display.projected.SetPropertyBlock(display.properties);
            }
        }
        void ReleaseIncidentResources()
        {
            if(incidentMaterial)ReleaseOwned(incidentMaterial);
            if(incidentPatch)ReleaseOwned(incidentPatch);
        }
    }
}
