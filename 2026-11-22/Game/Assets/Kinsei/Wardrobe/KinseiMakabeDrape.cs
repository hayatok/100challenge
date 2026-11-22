using System.IO;
using UnityEngine;

// Pose corrections for the two back panels of Makabe's coat, evaluated on the existing shoulder rig.
public sealed class KinseiMakabeDrape : MonoBehaviour
{
    SkinnedMeshRenderer coat;
    Transform spine,left,right;

    public void Fit(SkinnedMeshRenderer garment,Transform torso,Transform leftShoulder,Transform rightShoulder)
    {
        coat=garment;spine=torso;left=leftShoulder;right=rightShoulder;
    }

    void LateUpdate()
    {
        coat.SetBlendShapeWeight(0,LoadOnPanel(left,-1));
        coat.SetBlendShapeWeight(1,LoadOnPanel(right,1));
    }

    float LoadOnPanel(Transform shoulder,int side)
    {
        Vector3 arm=spine.InverseTransformDirection(-shoulder.up);
        float across=Mathf.Max(0,side*arm.x-.35f);
        return Mathf.SmoothStep(0,100,Mathf.InverseLerp(.18f,.91f,arm.z+.24f*across));
    }

    internal static void ReadFrames(Mesh mesh,BinaryReader reader)
    {
        foreach(string name in new[]{"Left sleeve pull","Right sleeve pull"})
        {
            var offset=new Vector3[mesh.vertexCount];
            var normalOffset=new Vector3[mesh.vertexCount];
            int count=reader.ReadInt32();
            for(int i=0;i<count;i++)
            {
                int vertex=reader.ReadUInt16();
                offset[vertex]=new Vector3(reader.ReadInt16(),reader.ReadInt16(),reader.ReadInt16())*.00001f;
                normalOffset[vertex]=new Vector3(reader.ReadInt16(),reader.ReadInt16(),reader.ReadInt16())*.0001f;
            }
            mesh.AddBlendShapeFrame(name,100,offset,normalOffset,null);
        }
        var detail=new Vector2[mesh.vertexCount];
        for(int i=0;i<detail.Length;i++)detail[i]=new Vector2(reader.ReadSingle(),reader.ReadSingle());
        mesh.uv2=detail;
    }
}
