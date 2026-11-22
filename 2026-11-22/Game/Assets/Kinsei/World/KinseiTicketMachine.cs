using System.IO;
using UnityEngine;

// Hardware is fixed to the counter. The paper and the lever keep their own animation parents.
public sealed class KinseiTicketMachine : MonoBehaviour
{
    Mesh casting;
    Material finish;

    public static Transform Install(Transform counter,Vector3 at,Material paintedIron)
    {
        var root=new GameObject("金星・鋳鉄製の手動発券機").transform;
        root.SetParent(counter,false);
        root.localPosition=at;
        var machine=root.gameObject.AddComponent<KinseiTicketMachine>();
        try { machine.Build(); }
        catch(InvalidDataException error){
            var cover=GameObject.CreatePrimitive(PrimitiveType.Cube);
            cover.name="印字機の鋳物外装";
            cover.transform.SetParent(root,false);
            cover.transform.localScale=new Vector3(.24f,.15f,.17f);
            var collider=cover.GetComponent<Collider>();collider.enabled=false;Destroy(collider);
            cover.GetComponent<MeshRenderer>().sharedMaterial=paintedIron;
            Debug.LogWarning("金星の発券機を簡易外装で表示しています。「"+error.Message+"」",machine);
        }
        return root;
    }

    static readonly Color32[] Paint={
        new Color32(37,62,57,255), new Color32(168,122,65,0),
        new Color32(120,117,105,0), new Color32(26,30,29,0),
        new Color32(206,188,144,0), new Color32(99,76,45,0)
    };
    static readonly Vector2[] Response={
        new Vector2(.32f,.47f),new Vector2(.78f,.55f),new Vector2(.75f,.53f),
        new Vector2(.33f,.32f),new Vector2(.10f,.34f),new Vector2(.68f,.38f)
    };

    void Build()
    {
        var source=Resources.Load<TextAsset>("KinseiPrintworks/TicketMachine");
        var shader=Resources.Load<Shader>("KinseiPrintworks/TicketIron");
        if(!source || !shader || !shader.isSupported)
            throw new InvalidDataException("TicketMachine or TicketIron is unavailable");
        var data=source.bytes;
        if(data.Length<12)throw new InvalidDataException("Truncated ticket machine header");
        using(var reader=new BinaryReader(new MemoryStream(data))){
            int signature=reader.ReadInt32(),count=reader.ReadInt32(),indices=reader.ReadInt32();
            if(signature!=0x3252504b || count<=0 || count>65535 || indices<=0 || indices%3!=0 ||
                reader.BaseStream.Length!=12L+25L*count+2L*indices)
                throw new InvalidDataException("Invalid ticket machine geometry");
            var vertices=new Vector3[count];var normals=new Vector3[count];
            var paint=new Color32[count];var surface=new Vector2[count];
            for(int i=0;i<count;i++){
                vertices[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());
                normals[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());
                int alloy=reader.ReadByte();
                if(alloy>=Paint.Length || !(vertices[i].sqrMagnitude<=1f) ||
                    !(normals[i].sqrMagnitude>.98f && normals[i].sqrMagnitude<1.02f))
                    throw new InvalidDataException("Invalid ticket machine vertex");
                paint[i]=Paint[alloy];surface[i]=Response[alloy];
            }
            var triangles=new int[indices];
            for(int i=0;i<indices;i++){
                triangles[i]=reader.ReadUInt16();
                if(triangles[i]>=count)throw new InvalidDataException("Invalid ticket machine index");
            }
            casting=new Mesh{name="金星発券機の鋳肌と金具",vertices=vertices,normals=normals,colors32=paint,uv=surface,triangles=triangles};
        }
        casting.RecalculateBounds();
        casting.UploadMeshData(true);
        finish=new Material(shader){name="金星の緑琺瑯と摺れた真鍮"};
        gameObject.AddComponent<MeshFilter>().sharedMesh=casting;
        gameObject.AddComponent<MeshRenderer>().sharedMaterial=finish;
    }

    void OnDestroy()
    {
        if(casting)Destroy(casting);
        if(finish)Destroy(finish);
    }
}
