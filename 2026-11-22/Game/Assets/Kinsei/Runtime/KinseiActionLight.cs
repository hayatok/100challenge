using UnityEngine;

// A small, reused set of trails keeps individual shots readable in the crowded room.
public sealed class KinseiActionLight : MonoBehaviour
{
    readonly LineRenderer[] traces=new LineRenderer[12];
    readonly float[] expiry=new float[12];
    Material ink;
    Light flare;
    int next;
    float flareUntil;
    void Awake()
    {
        ink=new Material(Resources.Load<Shader>("KinseiGlint"));
        for(int i=0;i<traces.Length;i++) {
            var go=new GameObject("残光");go.transform.SetParent(transform,false);
            var line=go.AddComponent<LineRenderer>();line.useWorldSpace=true;line.positionCount=2;
            line.sharedMaterial=ink;line.numCapVertices=3;line.enabled=false;
            traces[i]=line;
        }
        flare=new GameObject("発光").AddComponent<Light>();flare.transform.SetParent(transform,false);
        flare.type=LightType.Point;flare.color=new Color(1,.63f,.27f);flare.range=2.6f;flare.intensity=0;
    }
    public void Shot(Vector3 origin,Vector3 destination,bool enemy,bool subdued)
    {
        int i=next++%traces.Length;
        var line=traces[i]; Vector3 delta=destination-origin;
        line.startWidth=subdued?.012f:.022f;line.endWidth=.006f;
        line.startColor=enemy?new Color(.94f,.27f,.11f,.44f):new Color(1,.75f,.36f,.75f);
        line.endColor=new Color(1,.61f,.31f,.06f);
        line.SetPosition(0,origin+delta*.06f);line.SetPosition(1,destination);line.enabled=true;
        expiry[i]=Time.time+.065f;
        if(!subdued){flare.transform.position=origin;flare.intensity=1.4f;flareUntil=Time.time+.045f;}
    }
    void Update()
    {
        for(int i=0;i<traces.Length;i++)if(traces[i].enabled && Time.time>=expiry[i])traces[i].enabled=false;
        if(flare.intensity>0 && Time.time>=flareUntil)flare.intensity=0;
    }
    void OnDestroy(){if(ink!=null)Destroy(ink);}
}

