using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEditor;

[InitializeOnLoad] public static class YieldProof {
    static YieldProof(){if(SessionState.GetBool("measureYield",false))EditorApplication.update+=Start;}
    public static void Run(){
        SessionState.SetBool("measureYield",true);EditorApplication.update-=Start;EditorApplication.update+=Start;
        EditorApplication.EnterPlaymode();
    }
    static void Start(){
        if(!EditorApplication.isPlaying || !EditorApplication.isPlayingOrWillChangePlaymode)return;
        EditorApplication.update-=Start;SessionState.EraseBool("measureYield");
        Time.captureFramerate=60;
        new GameObject("検査").AddComponent<YieldMeasure>();
    }
}
public class YieldMeasure:MonoBehaviour{
    const BindingFlags F=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static T Val<T>(object a,string n)=>(T)a.GetType().GetField(n,F).GetValue(a);
    static string path=Path.GetFullPath(Path.Combine(Application.dataPath,"../..","frames.csv"));
    class Set{
        public KinseiActor actor;public int variant; public string prior;
        public Transform root,L,R,lk,rk;
        public SkinnedMeshRenderer suit,hand,face;
        public Mesh bake=new Mesh(),palm=new Mesh();
        public Vector3[] ls,rs;public MeshFilter lmesh,rmesh;
        public int[] leftBand,rightBand,fingers,kneeFaces;
        TrouserSection envelope;
        public Set(int v,string p,int number){
            variant=v;prior=p;root=new GameObject("test "+v+p).transform;
            root.position=new Vector3(number*4,0,0);actor=root.gameObject.AddComponent<KinseiActor>();actor.Init("guard",v);
            actor.SetAttentionTarget(root.position+new Vector3(.34f,1.56f,1.65f));
            L=Val<Transform>(actor,"leftShoe");R=Val<Transform>(actor,"rightShoe");lk=Val<Transform>(actor,"lk");rk=Val<Transform>(actor,"rk");
            lmesh=L.GetComponentsInChildren<MeshFilter>().First(x=>x.GetComponent<Renderer>().enabled);rmesh=R.GetComponentsInChildren<MeshFilter>().First(x=>x.GetComponent<Renderer>().enabled);
            ls=lmesh.sharedMesh.vertices;rs=rmesh.sharedMesh.vertices;
            suit=actor.GetComponentsInChildren<SkinnedMeshRenderer>().First(x=>x.name.StartsWith("Tailored"));
            face=Val<SkinnedMeshRenderer>(actor,"faceRenderer");hand=Val<SkinnedMeshRenderer>(actor,"rightHandRenderer");
            var rest=suit.sharedMesh.vertices;
            leftBand=Enumerable.Range(0,rest.Length).Where(i=>rest[i].x<0 && rest[i].y>.34f && rest[i].y<.65f).ToArray();
            rightBand=Enumerable.Range(0,rest.Length).Where(i=>rest[i].x>0 && rest[i].y>.34f && rest[i].y<.65f).ToArray();
            var tri=suit.sharedMesh.triangles;var weights=suit.sharedMesh.boneWeights;
            var near=new HashSet<int>(Enumerable.Range(0,rest.Length).Where(i=>(weights[i].boneIndex0==8||weights[i].boneIndex0==9) && rest[i].y>.34f && rest[i].y<.88f));
            var chosen=new List<int>();
            for(int i=0;i<tri.Length;i+=3)if(near.Contains(tri[i])&&near.Contains(tri[i+1])&&near.Contains(tri[i+2])){
                chosen.Add(tri[i]);chosen.Add(tri[i+1]);chosen.Add(tri[i+2]);
            }
            kneeFaces=chosen.ToArray();
            var hv=hand.sharedMesh.vertices;envelope=new TrouserSection(kneeFaces,hv);fingers=Enumerable.Range(0,hv.Length).Where(i=>hv[i].y<-.092f).ToArray();
            Debug.Log($"PROOF skin v{v}/{p} {suit.name} {leftBand.Length}+{rightBand.Length} knee vertices, {ls.Length}/{rs.Length} shoe vertices, hand {fingers.Length}, mouth track {Val<byte[]>(actor,"hallMouth")?.Length}");
        }
        static Vector3 Closest(Vector3 p,Vector3 a,Vector3 b,Vector3 c){
            Vector3 ab=b-a,ac=c-a,ap=p-a;
            float d1=Vector3.Dot(ab,ap),d2=Vector3.Dot(ac,ap);
            if(d1<=0&&d2<=0)return a;
            Vector3 bp=p-b;float d3=Vector3.Dot(ab,bp),d4=Vector3.Dot(ac,bp);
            if(d3>=0&&d4<=d3)return b;
            float vc=d1*d4-d3*d2;
            if(vc<=0&&d1>=0&&d3<=0)return a+ab*(d1/(d1-d3));
            Vector3 cp=p-c;float d5=Vector3.Dot(ab,cp),d6=Vector3.Dot(ac,cp);
            if(d6>=0&&d5<=d6)return c;
            float vb=d5*d2-d1*d6;
            if(vb<=0&&d2>=0&&d6<=0)return a+ac*(d2/(d2-d6));
            float va=d3*d6-d5*d4;
            if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0)return b+(c-b)*((d4-d3)/(d4-d3+d5-d6));
            float total=va+vb+vc;return total==0?a:a+ab*(vb/total)+ac*(vc/total);
        }
        public void Write(StreamWriter csv,int n){
            suit.BakeMesh(bake);var cloth=bake.vertices;
            var right=rightBand.Select(i=>suit.transform.TransformPoint(cloth[i])).ToArray();
            float floorL=leftBand.Min(i=>suit.transform.TransformPoint(cloth[i]).y);
            float fingerDistance=float.NaN;
            float handSigned=float.NaN;
            if(n==0 || n==24 || n==52 || n==78 || n==150){
                hand.BakeMesh(palm);var hv=palm.vertices;var restHand=hand.sharedMesh.vertices;float closest=float.PositiveInfinity,deepest=float.PositiveInfinity;
                Vector3 bestHand=Vector3.zero,bestCloth=Vector3.zero,kneeSpot=Vector3.zero;
                float allClosest=float.PositiveInfinity,allDeep=0;Vector3 allHand=Vector3.zero,allCloth=Vector3.zero,deepHand=Vector3.zero,deepCloth=Vector3.zero;
                bool final=n==150;
                foreach(int i in final?Enumerable.Range(0,hv.Length):fingers){
                    var point=suit.transform.InverseTransformPoint(hand.transform.TransformPoint(hv[i]));float nearest=float.PositiveInfinity,signed=0;
                    for(int k=0;k<kneeFaces.Length;k+=3){
                        Vector3 A=cloth[kneeFaces[k]],B=cloth[kneeFaces[k+1]],C=cloth[kneeFaces[k+2]];
                        Vector3 d=point-Closest(point,A,B,C);if(d.sqrMagnitude>=nearest)continue;
                        nearest=d.sqrMagnitude;kneeSpot=point-d;signed=Mathf.Sign(Vector3.Dot(d,Vector3.Cross(B-A,C-A)))*Mathf.Sqrt(nearest);
                    }
                    if(signed<allDeep&&nearest<.040f*.040f){allDeep=signed;deepHand=point;deepCloth=kneeSpot;}
                    if(nearest<allClosest){allClosest=nearest;allHand=point;allCloth=kneeSpot;}
                    if(restHand[i].y>=-.092f)continue;
                    if(nearest<closest){closest=nearest;bestHand=point;bestCloth=kneeSpot;}
                    if(nearest<.025f*.025f)deepest=Mathf.Min(deepest,signed);
                }
                if(final){
                    if(variant==0 && prior=="guard"){
                        using(var writer=new BinaryWriter(File.Open(Path.Combine(Path.GetDirectoryName(path),"final-surfaces.bin"),FileMode.Create))){
                            writer.Write(hv.Length);writer.Write(cloth.Length);writer.Write(kneeFaces.Length);
                            foreach(var h in hv){var q=suit.transform.InverseTransformPoint(hand.transform.TransformPoint(h));writer.Write(q.x);writer.Write(q.y);writer.Write(q.z);}
                            foreach(var q in cloth){writer.Write(q.x);writer.Write(q.y);writer.Write(q.z);}
                            foreach(var idx in kneeFaces)writer.Write(idx);
                        }
                    }
                    var shoulder=Val<Transform>(actor,"ra");var wrist=Val<Transform>(actor,"rh");
                    var target=rk.TransformPoint(new Vector3(.012f,.018f,.063f))+root.up*.0605f-root.forward*.090f;
                    var wristTarget=target-Quaternion.LookRotation(Vector3.down,-root.forward)*new Vector3(0,-.077f,.013f);
                    Debug.Log($"CONTACT {variant}/{prior} local finger {bestHand.ToString("F4")} to knee {bestCloth.ToString("F4")} delta {(bestCloth-bestHand).ToString("F4")}; all palm {allHand.ToString("F4")} to knee {allCloth.ToString("F4")} gap {Mathf.Sqrt(allClosest):F5}m; deepest {allDeep:F5}m at {deepHand.ToString("F4")} to {deepCloth.ToString("F4")}; root-local shoulder {root.InverseTransformPoint(shoulder.position).ToString("F4")} wrist {root.InverseTransformPoint(wrist.position).ToString("F4")} wristTarget {root.InverseTransformPoint(wristTarget).ToString("F4")} required {Vector3.Distance(wristTarget,shoulder.position):F5}m; contact target {root.InverseTransformPoint(target).ToString("F4")}");
                }
                fingerDistance=Mathf.Sqrt(closest);handSigned=float.IsPositiveInfinity(deepest)?float.NaN:deepest;
            }
            var l=root.InverseTransformPoint(L.position);var r=root.InverseTransformPoint(R.position);
            var lowL=ls.Select(v=>lmesh.transform.TransformPoint(v)).OrderBy(v=>v.y).First()-root.position;
            var lowR=rs.Select(v=>rmesh.transform.TransformPoint(v)).OrderBy(v=>v.y).First()-root.position;
            var eye=Val<Transform[]>(actor,"eyes");
            hand.BakeMesh(palm);float upperDepth=envelope.Read(cloth,palm.vertices,suit.transform.worldToLocalMatrix*hand.transform.localToWorldMatrix,out int inside,out float nearestDepth,out int enclosed);
            float seamMm=actor.MeasureHallCuffSeamMillimetres();
            if(seamMm<0 || float.IsNaN(seamMm) || float.IsInfinity(seamMm))throw new InvalidOperationException("Guard cuff seam unavailable");
            var values=new[]{n/60f,l.x,l.y,l.z,r.x,r.y,r.z,lk.position.y,rk.position.y,lowL.x,lowL.y,lowL.z,lowR.x,lowR.y,lowR.z,floorL,right.Min(v=>v.y),fingerDistance,face.GetBlendShapeWeight(Val<int>(actor,"speechOpen")),eye[0].localScale.y,eye[1].localScale.y,handSigned,upperDepth,(float)inside,nearestDepth,(float)enclosed,seamMm};
            csv.WriteLine(variant+","+prior+","+string.Join(",",values.Select(f=>f.ToString("F6",CultureInfo.InvariantCulture))));
        }
    }
    List<Set> sets=new List<Set>(); StreamWriter csv;int frame=-43;
    void Start(){
        try{
            foreach(int v in new[]{0,1})foreach(var s in new[]{"guard","walk"})sets.Add(new Set(v,s,sets.Count));
            csv=new StreamWriter(path);csv.WriteLine("variant,prior,t,lx,ly,lz,rx,ry,rz,leftKnee,rightKnee,lsoleX,lsoleY,lsoleZ,rsoleX,rsoleY,rsoleZ,leftCloth,rightCloth,fingerDistance,lipPct,eyeL,eyeR,handSigned,upperDepth,insideCount,nearestDepth,enclosed,cuffSeamMm");
        }catch(Exception e){Debug.LogException(e);EditorApplication.Exit(1);}
    }
    void Update(){
        if(csv==null)return;
        try{
            foreach(var s in sets){
                if(frame<=0){if(s.prior=="walk")s.root.position+=Vector3.forward*(1.6f/60);s.actor.Pose(s.prior,s.prior=="walk"?1.6f:0);}
                else s.actor.Pose("floor-yield",0);
                if(frame>=0)s.Write(csv,frame);
            }
            if(frame++==150){csv.Dispose();csv=null;Debug.Log("YIELD_MEASURE_PASS "+path);EditorApplication.Exit(0);}
        }catch(Exception e){csv?.Dispose();csv=null;Debug.LogException(e);EditorApplication.Exit(1);}
    }
}
