using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// All water patches lie on the same plane and share one reflected view.
public sealed class KinseiRainStreet : MonoBehaviour
{
    const float Surface = -.011f;
    readonly Plane[] frustum = new Plane[6];
    readonly List<Bounds> patches = new List<Bounds>();
    const int Edges=40;
    public const int WalkerCount=7; // Makabe and the six crew seats.
    struct Walker {
        public KinseiActor actor;
        public Vector3 last;
        public bool leftRaised,rightRaised;
    }
    readonly Walker[] walkers=new Walker[WalkerCount];
    readonly Vector4[] steps=new Vector4[8];
    const int CoverageSize=256;
    static readonly Vector4 DepthParams=new Vector4(.68f,.36f,.17f,.02f);
    static readonly Vector4 HeightScales=new Vector4(.26f,1.5f,0,0);
    readonly List<Vector2> edgeVectors=new List<Vector2>();
    readonly Vector2[] edgeUV=new Vector2[Edges];
    byte[] heights;
    Texture2D coverage;
    bool hasPicture;
    float lastReflectionTime;
    Matrix4x4 previousView,previousProjection;
    Rect previousCrop;
    Vector4 reflectionUV;
    readonly Vector3[] viewCorners=new Vector3[8];
    int nextStep;
    Camera reflection;
    RenderTexture picture;
    Material water;
    KinseiRainSplash splash;
    Mesh mesh;

    void Awake()
    {
        BuildPatches();
        if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Null)return;
        var shader=Resources.Load<Shader>("KinseiWetPavement");
        if(!shader || !shader.isSupported)return;
        water=new Material(shader);
        int size=heights!=null ? CoverageSize : 1;
        coverage=new Texture2D(size,size,TextureFormat.RG16,false,true) {
            name="Street water height fields",wrapMode=TextureWrapMode.Repeat,filterMode=FilterMode.Bilinear
        };
        coverage.LoadRawTextureData(heights ?? new byte[]{128,128});
        coverage.Apply(false,true);
        water.SetTexture("_Coverage",coverage);
        water.SetVector("_DepthParams",DepthParams);
        water.SetVector("_HeightScales",HeightScales);
        splash=new KinseiRainSplash();
        foreach(string name in new[]{"Asphalt","Basin","Ripple"}) {
            var texture=Resources.Load<Texture2D>("KinseiRainStreet/"+name);
            if(texture)water.SetTexture("_"+name,texture);
        }
        var go=new GameObject("Gutter reflection camera"){hideFlags=HideFlags.HideAndDontSave};
        reflection=go.AddComponent<Camera>();reflection.enabled=false;
    }

    void BuildPatches()
    {
        var raw=Resources.Load<TextAsset>("KinseiRainStreet/Coverage");
        heights=raw ? raw.bytes : null;
        if(heights!=null && heights.Length!=CoverageSize*CoverageSize*2)heights=null;
        var vertices=new List<Vector3>();
        var uvs=new List<Vector2>();
        var faces=new List<int>();
        var random=new System.Random(1927);
        // Shallow depressions interrupted by dry aggregate and the raised entry curbs.
        Vector4[] hollows={
            new Vector4(-.55f,-10.67f,1.48f,.51f),new Vector4(-3.52f,-10.85f,1.48f,.51f),
            new Vector4(-6.95f,-12.18f,2.28f,.40f),new Vector4(-11.25f,-11.26f,1.95f,.44f),
            new Vector4(-15.26f,-10.67f,1.78f,.40f),new Vector4(-19.49f,-10.82f,2.24f,.48f),
            new Vector4(-23.83f,-11.18f,1.75f,.36f),new Vector4(-26.45f,-11.27f,.84f,.31f),
            new Vector4(5.5f,-10.73f,2.16f,.54f),new Vector4(8.83f,-12.24f,1.12f,.35f)
        };
        foreach(var h in hollows) {
            int first=vertices.Count;
            vertices.Add(new Vector3(h.x,Surface,h.y));uvs.Add(Vector2.zero);
            const int edges=Edges;
            for(int i=0;i<edges;i++) {
                float a=i*2*Mathf.PI/edges;
                var uv=new Vector2(Mathf.Cos(a),Mathf.Sin(a));
                float r=.86f+.09f*Mathf.Sin(a*3+first)+.06f*(float)random.NextDouble();
                float x=uv.x*r;
                vertices.Add(new Vector3(h.x+h.z*x,Surface,h.y+h.w*(uv.y*r+.28f*Mathf.Sin(3*x))));
                var vertex=vertices[vertices.Count-1];
                edgeVectors.Add(new Vector2(vertex.x-h.x,vertex.z-h.y));
                edgeUV[i]=uv;
                uvs.Add(uv);
                faces.Add(first);faces.Add(first+1+(i+1)%edges);faces.Add(first+1+i);
            }
            patches.Add(new Bounds(new Vector3(h.x,Surface,h.y),new Vector3(h.z*2.1f,.04f,h.w*2.6f)));
        }
        mesh=new Mesh{name="Gutter pools"};mesh.SetVertices(vertices);mesh.SetUVs(0,uvs);mesh.SetTriangles(faces,0);
    }

    bool InWater(Vector3 sole)
    {
        // NavMesh projection and the controller place feet a few centimetres above the asphalt.
        if(Mathf.Abs(sole.y-Surface)>.055f)return false;
        for(int patch=0;patch<patches.Count;patch++) {
            Bounds box=patches[patch];
            if(Mathf.Abs(sole.x-box.center.x)>box.extents.x || Mathf.Abs(sole.z-box.center.z)>box.extents.z)continue;
            Vector2 delta=new Vector2(sole.x-box.center.x,sole.z-box.center.z);
            int first=patch*Edges;
            for(int k=0;k<Edges;k++) {
                int next=(k+1)%Edges;
                var a=edgeVectors[first+k];var b=edgeVectors[first+next];
                float determinant=a.x*b.y-a.y*b.x;
                float u=(delta.x*b.y-delta.y*b.x)/determinant;
                float v=(a.x*delta.y-a.y*delta.x)/determinant;
                if(u<0 || v<0 || u+v>1)continue;
                float rim=1-(edgeUV[k]*u+edgeUV[next]*v).magnitude;
                float grain=SampleHeight(sole,HeightScales.x,0);
                float basin=SampleHeight(sole,HeightScales.y,1);
                float depth=rim*DepthParams.x+(basin-.5f)*DepthParams.y-grain*DepthParams.z;
                if(depth>DepthParams.w)return true;
            }
        }
        return false;
    }

    float SampleHeight(Vector3 point,float scale,int channel)
    {
        if(heights==null)return 128f/255f;
        float x=point.x/scale*CoverageSize-.5f,z=point.z/scale*CoverageSize-.5f;
        int left=Mathf.FloorToInt(x),bottom=Mathf.FloorToInt(z);
        float tx=x-left,tz=z-bottom;
        const int mask=CoverageSize-1;
        int l=(left&mask)*2+channel,r=((left+1)&mask)*2+channel;
        int low=(bottom&mask)*CoverageSize*2,high=((bottom+1)&mask)*CoverageSize*2;
        return Mathf.Lerp(Mathf.Lerp(heights[low+l],heights[low+r],tx),
            Mathf.Lerp(heights[high+l],heights[high+r],tx),tz)/255f;
    }

    public void ResetContacts()
    {
        System.Array.Clear(walkers,0,walkers.Length);
        System.Array.Clear(steps,0,steps.Length);
        nextStep=0;hasPicture=false;
    }

    public void Track(int seat,KinseiActor actor,bool walking,float time,bool record=false)
    {
        if(seat<0 || seat>=walkers.Length)return;
        ref Walker walker=ref walkers[seat];
        if(!actor){walker=default;return;}
        var at=actor.transform.position;
        var displacement=at-walker.last;
        bool moving=walking && walker.actor==actor && displacement.sqrMagnitude<.45f*.45f &&
            displacement.x*displacement.x+displacement.z*displacement.z>1e-10f;
        walker.actor=actor;walker.last=at;
        if(!moving || patches.Count==0 || Mathf.Abs(at.y)>.10f) {
            walker.leftRaised=walker.rightRaised=false;return;
        }
        SampleFoot(actor.StreetShoe(true),at.y,time,ref walker.leftRaised,record,seat,"left");
        SampleFoot(actor.StreetShoe(false),at.y,time,ref walker.rightRaised,record,seat,"right");
    }

    void SampleFoot(Transform ankle,float floor,float time,ref bool raised,bool record,int seat,string foot)
    {
        if(!ankle)return;
        // Support point of the posed shoe sole ellipsoid along world -Y.
        var m=ankle.localToWorldMatrix;
        var radii=new Vector3(.056f,.017f,.124f);
        var down=new Vector3(-m.m10*radii.x,-m.m11*radii.y,-m.m12*radii.z).normalized;
        var sole=m.MultiplyPoint3x4(new Vector3(0,-.052f,.056f)+Vector3.Scale(radii,down));
        float clearance=sole.y-floor;
        if(clearance>.038f)raised=true;
        if(!raised || clearance>.019f)return;
        raised=false;
        if(!InWater(sole))return;
        steps[nextStep]=new Vector4(sole.x,sole.z,time,1);
        if(record)Debug.Log($"KINSEI_WATER_CONTACT t={time:F3} seat={seat} foot={foot} x={sole.x:F3} z={sole.z:F3}");
        nextStep=(nextStep+1)%steps.Length;
    }

    static bool ClearFromRoom(Vector3 eye,Bounds patch)
    {
        var centre=patch.center+Vector3.up*.035f;
        var across=Vector3.right*(patch.extents.x*.72f);
        var along=Vector3.forward*(patch.extents.z*.65f);
        return !Physics.Linecast(eye,centre,~0,QueryTriggerInteraction.Ignore)
            || !Physics.Linecast(eye,centre+across,~0,QueryTriggerInteraction.Ignore)
            || !Physics.Linecast(eye,centre-across,~0,QueryTriggerInteraction.Ignore)
            || !Physics.Linecast(eye,centre+along,~0,QueryTriggerInteraction.Ignore)
            || !Physics.Linecast(eye,centre-along,~0,QueryTriggerInteraction.Ignore);
    }

    // Project the clipped box, including the crown's height and lateral travel. A box
    // straddling the near plane needs the cut edges, not the corners behind the eye.
    void ProjectPatch(Bounds patch,Matrix4x4 view,Matrix4x4 projection,float near,ref Vector2 low,ref Vector2 high)
    {
        var ext=patch.extents+new Vector3(.15f,.045f,.15f);
        var center=patch.center+Vector3.up*.035f;
        for(int i=0;i<8;i++) {
            Vector3 corner=center+new Vector3((i&1)==0?-ext.x:ext.x,(i&2)==0?-ext.y:ext.y,(i&4)==0?-ext.z:ext.z);
            var v=view.MultiplyPoint3x4(corner);
            viewCorners[i]=v;
            if(v.z<=-near)IncludeViewport(v,projection,ref low,ref high);
        }
        for(int i=0;i<8;i++)
            for(int bit=1;bit<=4;bit*=2) {
                if((i&bit)!=0)continue;
                var a=viewCorners[i];var b=viewCorners[i|bit];
                if((a.z<=-near)==(b.z<=-near))continue;
                var cut=Vector3.LerpUnclamped(a,b,(-near-a.z)/(b.z-a.z));
                IncludeViewport(cut,projection,ref low,ref high);
            }
    }

    static void IncludeViewport(Vector3 view,Matrix4x4 projection,ref Vector2 low,ref Vector2 high)
    {
        var ndc=projection.MultiplyPoint(view);
        var uv=new Vector2(ndc.x*.5f+.5f,ndc.y*.5f+.5f);
        low=Vector2.Min(low,uv);high=Vector2.Max(high,uv);
    }

    public void Draw(Camera eye,float time,bool tactical,bool paused,bool behindWalls)
    {
        if(!water)return;
        GeometryUtility.CalculateFrustumPlanes(eye,frustum);
        var view=eye.worldToCameraMatrix;
        var projection=eye.projectionMatrix;
        var low=new Vector2(float.MaxValue,float.MaxValue);
        var high=new Vector2(float.MinValue,float.MinValue);
        foreach(var patch in patches) {
            if(!GeometryUtility.TestPlanesAABB(frustum,patch) || (behindWalls && !ClearFromRoom(eye.transform.position,patch)))continue;
            ProjectPatch(patch,view,projection,eye.nearClipPlane,ref low,ref high);
        }
        if(low.x>high.x)return;
        Rect crop=Rect.MinMaxRect(Mathf.Clamp01(low.x-.04f),Mathf.Clamp01(low.y-.04f),
            Mathf.Clamp01(high.x+.04f),Mathf.Clamp01(high.y+.04f));
        if(crop.width<.001f || crop.height<.001f)return;
        if(crop.width*crop.height>.82f)crop=new Rect(0,0,1,1);
        // Size is independent of the moving crop. Keep one target across both camera modes.
        int width=Mathf.Clamp(eye.pixelWidth/4,144,352);
        int height=Mathf.Clamp(eye.pixelHeight/5,64,176);
        if(!picture || picture.width!=width || picture.height!=height) {
            ReleasePicture();
            picture=new RenderTexture(width,height,16,RenderTextureFormat.DefaultHDR){name="Gutter reflected street",filterMode=FilterMode.Bilinear};
            picture.Create();hasPicture=false;
        }
        bool moved=view!=previousView || projection!=previousProjection || crop!=previousCrop;
        if(!hasPicture || moved || (!paused && time-lastReflectionTime>=1f/30)) {
            RenderReflection(eye,crop);
            previousView=view;previousProjection=projection;previousCrop=crop;
            lastReflectionTime=time;
            reflectionUV=new Vector4(1/crop.width,1/crop.height,-crop.xMin/crop.width,-crop.yMin/crop.height);
            hasPicture=true;
        }
        water.SetTexture("_Reflection",picture);water.SetVector("_ReflectionUV",reflectionUV);
        water.SetVectorArray("_Steps",steps);water.SetFloat("_Clock",time);
        water.SetFloat("_Strength",tactical?.48f:.90f);
        Graphics.DrawMesh(mesh,Matrix4x4.identity,water,0,eye,0,null,ShadowCastingMode.Off,false,null,LightProbeUsage.Off);
        if(!tactical)splash?.Draw(eye,frustum,picture,reflectionUV,steps,time,Surface);
    }

    void RenderReflection(Camera eye,Rect crop)
    {
        reflection.CopyFrom(eye);reflection.enabled=false;
        reflection.targetTexture=picture;reflection.rect=new Rect(0,0,1,1);
        reflection.allowMSAA=false;reflection.depthTextureMode=DepthTextureMode.None;
        reflection.useOcclusionCulling=false;
        Matrix4x4 flip=Matrix4x4.Scale(new Vector3(1,-1,1));flip.m13=2*Surface;
        var view=eye.worldToCameraMatrix*flip;
        reflection.transform.SetPositionAndRotation(flip.MultiplyPoint(eye.transform.position),
            Quaternion.LookRotation(flip.MultiplyVector(eye.transform.forward),flip.MultiplyVector(eye.transform.up)));
        reflection.worldToCameraMatrix=view;
        var normal=view.MultiplyVector(Vector3.up);
        var point=view.MultiplyPoint(new Vector3(0,Surface+.007f,0));
        reflection.projectionMatrix=eye.projectionMatrix;
        var oblique=reflection.CalculateObliqueMatrix(new Vector4(normal.x,normal.y,normal.z,-Vector3.Dot(point,normal)));
        var zoom=Matrix4x4.identity;
        zoom.m00=1/crop.width;zoom.m03=(1-2*crop.center.x)/crop.width;
        zoom.m11=1/crop.height;zoom.m13=(1-2*crop.center.y)/crop.height;
        reflection.projectionMatrix=zoom*oblique;
        reflection.cullingMatrix=reflection.projectionMatrix*view;
        bool inverted=GL.invertCulling;
        int scenePixelLights=QualitySettings.pixelLightCount;
        try {
            // Limit extra forward lighting passes in the low-resolution reflection.
            // Forced pixel lights, including the receiver spill, keep their authored priority.
            if(scenePixelLights>1)QualitySettings.pixelLightCount=1;
            GL.invertCulling=!inverted;
            reflection.Render();
        } finally {
            GL.invertCulling=inverted;
            if(scenePixelLights>1)QualitySettings.pixelLightCount=scenePixelLights;
        }
    }
    void ReleasePicture()
    {
        if(!picture)return;
        reflection.targetTexture=null;picture.Release();Destroy(picture);
    }
    void OnDestroy()
    {
        ReleasePicture();if(reflection)Destroy(reflection.gameObject);if(mesh)Destroy(mesh);if(water)Destroy(water);
        splash?.Release();if(coverage)Destroy(coverage);
    }
}
