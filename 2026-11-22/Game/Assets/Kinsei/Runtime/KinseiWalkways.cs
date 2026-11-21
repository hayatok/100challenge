using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

// The same authored collision surfaces define the routes used by companions and opposing actors.
public sealed class KinseiWalkways : MonoBehaviour
{
    NavMeshData mesh;
    NavMeshDataInstance registration;
    public bool Ready => registration.valid;

    public void Rebuild(Transform house)
    {
        var sources=new List<NavMeshBuildSource>();
        NavMeshBuilder.CollectSources(house,~0,NavMeshCollectGeometry.PhysicsColliders,0,
            new List<NavMeshBuildMarkup>(),sources);
        var settings=NavMesh.GetSettingsByIndex(0);
        settings.agentRadius=.255f;settings.agentHeight=1.68f;settings.agentClimb=.30f;
        settings.agentSlope=44;settings.minRegionArea=.8f;
        settings.overrideVoxelSize=true;settings.voxelSize=.065f;
        mesh=NavMeshBuilder.BuildNavMeshData(settings,sources,new Bounds(new Vector3(0,2,-2.7f),new Vector3(36,13,32)),Vector3.zero,Quaternion.identity);
        if(mesh!=null)registration=NavMesh.AddNavMeshData(mesh);
    }

    public bool GetPath(Vector3 from,Vector3 to,NavMeshPath route)
    {
        if(!Ready || !NavMesh.SamplePosition(from,out var begin,.92f,NavMesh.AllAreas)
            || !NavMesh.SamplePosition(to,out var end,1.07f,NavMesh.AllAreas))return false;
        if(Mathf.Abs(begin.position.y-from.y)>.7f || Mathf.Abs(end.position.y-to.y)>.7f)return false;
        return NavMesh.CalculatePath(begin.position,end.position,NavMesh.AllAreas,route) && route.status==NavMeshPathStatus.PathComplete;
    }

    public bool Project(Vector3 at,out Vector3 onFloor)
    {
        bool found=NavMesh.SamplePosition(at,out var sample,.75f,NavMesh.AllAreas);
        onFloor=sample.position;
        return found;
    }
    void OnDestroy(){if(registration.valid)registration.Remove();if(mesh!=null)Destroy(mesh);}
}

