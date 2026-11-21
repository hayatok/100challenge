using System.Collections.Generic;
using System.IO;
using UnityEngine;

public sealed class KinseiWardrobeBinding : MonoBehaviour
{
    const string Folder = "KinseiWardrobe/";
    Mesh garment;
    Material fabric;

    // Called once at the end of KinseiActor.Init, before the first pose.
    public static void Dress(GameObject actor, string role, int variant)
    {
        if (actor.GetComponent<KinseiWardrobeBinding>()) return;
        Transform pelvis = actor.transform.Find("Pelvis");
        if (!pelvis) return;
        Transform spine = pelvis.Find("Spine");
        if (!spine) return;
        Transform left = spine.Find("Left shoulder"), right = spine.Find("Right shoulder");
        Transform leftHip = null, rightHip = null;
        foreach (Transform child in pelvis)
        {
            if (child.name != "Hip") continue;
            if (child.localPosition.x < 0) leftHip = child;
            else rightHip = child;
        }
        if (!left || !right || !leftHip || !rightHip) return;
        var bones = new[] {pelvis,spine,left,left.Find("Elbow"),right,right.Find("Elbow"),
                           leftHip,leftHip.Find("Knee"),rightHip,rightHip.Find("Knee")};
        foreach (Transform bone in bones) if (!bone) return;

        bool gown = role == "stage-singer";
        if (gown) System.Array.Resize(ref bones,11);
        if (gown) bones[10]=spine.Find("Head");
        string cut = role == "tatsu" ? "Double" : "Single";
        string palette = role == "tatsu" ? "Rust" : role == "boss" ? "Cream" :
            role == "kaji" ? "Olive" : role == "brother" ? "Sage" : "Navy";
        bool makabe=role=="makabe";
        TextAsset data = Resources.Load<TextAsset>(makabe ? "KinseiMakabe/MakabeCut" : gown ? "KinseiStage/Camellia" : Folder + cut);
        Texture2D color = Resources.Load<Texture2D>(makabe ? "KinseiMakabe/MakabeWool" : gown ? "KinseiStage/CamelliaSatin" : role == "stage-pianist" ? "KinseiStage/DinnerJacket" : Folder + palette);
        Texture2D normal = makabe ? Resources.Load<Texture2D>("KinseiMakabe/MakabeWoolNormal") : gown ? Resources.Load<Texture2D>("KinseiCast/WoolNormal") : Resources.Load<Texture2D>(Folder + cut + "Normal");
        if (!data || !color || !normal) return;
        var binding = actor.AddComponent<KinseiWardrobeBinding>();
        var surface = new GameObject(gown ? "Camellia bias gown and hair comb" : "Tailored " + palette + " suit");
        surface.transform.SetParent(actor.transform,false);
        // The mesh is in canonical actor coordinates. Retain role-specific pelvis width in rest and motion.
        Matrix4x4 canonical = actor.transform.localToWorldMatrix * Matrix4x4.Scale(pelvis.localScale);
        var bind = new Matrix4x4[bones.Length];
        for (int i=0;i<bones.Length;i++) bind[i] = bones[i].worldToLocalMatrix * canonical;
        binding.garment = ReadMesh(data,bind,makabe);
        binding.fabric = makabe ? new Material(Resources.Load<Material>("KinseiMakabe/Worsted")) : new Material(Shader.Find("Standard"));
        binding.fabric.name=palette+" tailored wool";
        binding.fabric.mainTexture=color;
        binding.fabric.SetTexture("_BumpMap",normal);
        binding.fabric.SetFloat("_BumpScale",gown ? .16f : .65f);
        binding.fabric.SetFloat("_Glossiness",gown ? .52f : .22f);
        binding.fabric.EnableKeyword("_NORMALMAP");
        var renderer = surface.AddComponent<SkinnedMeshRenderer>();
        renderer.sharedMesh = binding.garment;
        renderer.sharedMaterial = binding.fabric;
        renderer.bones = bones;
        renderer.rootBone = pelvis;
        renderer.quality = SkinQuality.Bone4;
        renderer.localBounds = new Bounds(new Vector3(0,-.14f,0),new Vector3(1.9f,2.15f,2f));

        if(makabe)surface.AddComponent<KinseiMakabeDrape>().Fit(renderer,spine,left,right);

        var materials = new HashSet<string> {"Worsted wool","Jacket collar and lapels","Ivory shirt",
                                               "Burgundy silk","Seams and soles"};
        foreach (Renderer old in pelvis.GetComponentsInChildren<Renderer>(true))
        {
            if (!old.sharedMaterial || !materials.Contains(old.sharedMaterial.name)) continue;
            Transform mount = old.transform.parent;
            // Attached shoes, the face and the hands retain the actor's original renderers.
            if (System.Array.IndexOf(bones,mount) < 0) continue;
            old.enabled=false;
        }
    }

    static Mesh ReadMesh(TextAsset source,Matrix4x4[] bind,bool makabe)
    {
        using var reader = new BinaryReader(new MemoryStream(source.bytes));
        int count=reader.ReadInt32(), indexCount=reader.ReadInt32();
        var positions=new Vector3[count];
        var normals=new Vector3[count];
        var uv=new Vector2[count];
        var weights=new BoneWeight[count];
        for(int i=0;i<count;i++)
        {
            positions[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());
            normals[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());
            uv[i]=new Vector2(reader.ReadSingle(),reader.ReadSingle());
            weights[i]=new BoneWeight {boneIndex0=reader.ReadByte(),boneIndex1=reader.ReadByte(),
                boneIndex2=reader.ReadByte(),boneIndex3=reader.ReadByte(),weight0=reader.ReadSingle(),
                weight1=reader.ReadSingle(),weight2=reader.ReadSingle(),weight3=reader.ReadSingle()};
        }
        var triangles=new int[indexCount];
        for(int i=0;i<indexCount;i++) triangles[i]=reader.ReadUInt16();
        var mesh=new Mesh {name=source.name+" tailored suit",vertices=positions,normals=normals,
                           uv=uv,triangles=triangles,bindposes=bind,boneWeights=weights};
        if(makabe)KinseiMakabeDrape.ReadFrames(mesh,reader);
        mesh.RecalculateTangents();
        mesh.RecalculateBounds();
        return mesh;
    }

    void OnDestroy()
    {
        if(garment) Destroy(garment);
        if(fabric) Destroy(fabric);
    }
}

