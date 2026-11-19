using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Evac.Editor
{
    public static class CharacterContactInspection
    {
        static Camera camera;
        static WorldView world;
        static RenderTexture target;
        static string folder;
        static int frame, lastFrame=-1;
        static Func<Vector3,float> floorHeight;
        const string Requested="Evac.CharacterContactInspection";
        [InitializeOnLoadMethod]
        static void Resume()
        {
            if(SessionState.GetBool(Requested,false))EditorApplication.playModeStateChanged+=OnPlay;
        }
        static void OnPlay(PlayModeStateChange change)
        {
            if(change!=PlayModeStateChange.EnteredPlayMode)return;
            SessionState.EraseBool(Requested);
            folder=Environment.GetEnvironmentVariable("EVAC_CONTACT_OUTPUT");
            Setup();
        }
        public static void Run()
        {
            folder=Environment.GetEnvironmentVariable("EVAC_CONTACT_OUTPUT");
            Directory.CreateDirectory(folder);
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            SessionState.SetBool(Requested,true);
            EditorApplication.EnterPlaymode();
        }

        static void Setup()
        {
            foreach(var existing in UnityEngine.Object.FindObjectsByType<Camera>(FindObjectsSortMode.None))existing.tag="Untagged";
            camera=new GameObject("Inspection camera").AddComponent<Camera>();
            camera.tag="MainCamera";
            camera.fieldOfView=36;
            target=new RenderTexture(960,540,24);
            camera.targetTexture=target;
            world=new GameObject("Market").AddComponent<WorldView>();
            world.Build(0);
            var sampler=typeof(WorldView).GetMethod("ActorFloor",BindingFlags.Instance|BindingFlags.NonPublic);
            if(sampler!=null)floorHeight=(Func<Vector3,float>)sampler.CreateDelegate(typeof(Func<Vector3,float>),world);
            EditorApplication.update+=Step;
        }

        static void Measure(string label)
        {
            var shader=AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/Editor/CharacterContactInspection.compute");
            var field=typeof(WorldView).GetField("batches",BindingFlags.Instance|BindingFlags.NonPublic);
            var batches=(IDictionary)field.GetValue(world);
            using var report=new StreamWriter(Path.Combine(folder,label+"-contact.csv"));
            report.WriteLine("mesh,part,floor_at_root,minimum_world_y,minimum_clearance,contact_x,contact_z");
            foreach(DictionaryEntry entry in batches)
            {
                object batch=entry.Value;
                T Read<T>(string name)=>(T)batch.GetType().GetField(name).GetValue(batch);
                var matrices=Read<List<Matrix4x4>>("transforms");
                if(matrices.Count==0)continue;
                string name=Read<Mesh>("mesh").name;
                var bytes=Resources.Load<TextAsset>("World/"+name);
                using var reader=new BinaryReader(new MemoryStream(bytes.bytes));
                int count=reader.ReadInt32();
                var bind=new Vector4[count];
                for(int i=0;i<count;i++)
                {
                    float x=reader.ReadSingle(),y=reader.ReadSingle(),z=reader.ReadSingle();
                    reader.BaseStream.Position+=6;
                    bind[i]=new Vector4(x,y,z,reader.ReadByte()%16);
                    reader.BaseStream.Position+=4;
                }
                using var input=new ComputeBuffer(count,16);
                using var output=new ComputeBuffer(count,12);
                input.SetData(bind);
                shader.SetBuffer(0,"bindVertices",input);
                shader.SetBuffer(0,"deformed",output);
                shader.SetInt("vertexCount",count);
                shader.SetMatrix("actorToWorld",matrices[0]);
                shader.SetVector("pose",Read<List<Vector4>>("poses")[0]);
                shader.SetVector("form",Read<List<Vector4>>("forms")[0]);
                shader.SetVector("leftFoot",Read<List<Vector4>>("left")[0]);
                shader.SetVector("rightFoot",Read<List<Vector4>>("right")[0]);
                shader.SetVector("aid",Read<List<Vector4>>("aid")[0]);
                shader.Dispatch(0,(count+63)/64,1,1);
                var posed=new Vector3[count];
                output.GetData(posed);
                float[] minHeight={999,999,999},minClearance={999,999,999};
                Vector3[] contacts=new Vector3[3];
                for(int i=0;i<count;i++)
                {
                    int bone=(int)bind[i].w;
                    int part=bone==13?0:bone==11 || bone==12?1:bone==0 && bind[i].y>1.06f && bind[i].y<1.43f?2:-1;
                    if(part<0)continue;
                    minHeight[part]=Mathf.Min(minHeight[part],posed[i].y);
                    if(floorHeight!=null){
                        float clearance=posed[i].y-floorHeight(posed[i]);
                        if(clearance<minClearance[part]){
                            minClearance[part]=clearance;
                            contacts[part]=posed[i];
                        }
                    }
                }
                bool check=Environment.GetEnvironmentVariable("EVAC_CONTACT_BASELINE")!="1";
                for(int i=0;check && i<3;i++)
                    if(floorHeight==null || minClearance[i]<-.002f || minClearance[i]>(i==0?.045f:.018f))
                        throw new InvalidDataException($"{name} part {i} clearance {minClearance[i]:F4} m on {label}");
                string[] parts={"head","boots","torso"};
                for(int i=0;i<3;i++)report.WriteLine(FormattableString.Invariant(
                    $"{name},{parts[i]},{floorHeight?.Invoke(matrices[0].GetColumn(3)):F4},{minHeight[i]:F4},{(floorHeight!=null?(float?)minClearance[i]:null):F4},{contacts[i].x:F3},{contacts[i].z:F3}"));
            }
        }

        static void Step()
        {
            try
            {
                if(lastFrame==Time.frameCount)return;
                lastFrame=Time.frameCount;
                const float dt=1f/30f;
                int localFrame=frame%121;
                bool raised=frame>=121;
                bool fallen=localFrame>=30;
                float advance=Mathf.Min(localFrame,30)*dt*.7f;
                Vector3 center=new Vector3(raised?10:0,0,(raised?60:-8)+advance);
                camera.transform.position=center+(raised?new Vector3(-3.2f,2.8f,-2.6f):new Vector3(1.1f,fallen?.72f:1.34f,3.7f));
                camera.transform.LookAt(center+Vector3.up*(fallen?.39f:.95f));
                for(int i=0;i<3;i++)
                {
                    Vector3 feet=center+Vector3.right*(i-1)*.98f;
                    if(raised && i==1)feet+=Vector3.forward*1.3f;
                    Vector3 hit=raised?(i==0?Vector3.forward:i==1?Vector3.right:Vector3.back):Vector3.back;
                    world.DrawActor((raised?30:20)+i,i,0,feet,0,fallen?0:.7f,fallen?0:1,false,false,dt,0,hit);
                }
                world.EndFrame();
                if(localFrame==20 || localFrame==37 || localFrame==53 || localFrame==120)
                {
                    camera.Render();
                    RenderTexture.active=target;
                    var image=new Texture2D(target.width,target.height,TextureFormat.RGB24,false);
                    image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);
                    image.Apply();
                    File.WriteAllBytes(Path.Combine(folder,"contact-"+frame+".png"),image.EncodeToPNG());
                    UnityEngine.Object.DestroyImmediate(image);
                    RenderTexture.active=null;
                }
                if(localFrame==53)Measure(raised?"walkway":"street");
                if(++frame>241) {EditorApplication.update-=Step;EditorApplication.Exit(0);}
            }
            catch(Exception e){Debug.LogException(e);EditorApplication.update-=Step;EditorApplication.Exit(1);}
        }
    }
}
