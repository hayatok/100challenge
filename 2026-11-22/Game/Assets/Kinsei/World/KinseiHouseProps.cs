using UnityEngine;

// Printed ephemera use actual production lettering; distance signs remain modeled in KinseiWorld.
public sealed class KinseiHouseProps : MonoBehaviour
{
    Material metal, lacquer;
    public void Dress()
    {
        metal=Surface(new Color(.52f,.32f,.105f),.78f,.62f);
        lacquer=Surface(new Color(.185f,.032f,.043f),.33f,.72f);
        Framed("堺の奏者・中継卓","Art/sakai-broadcast", new Vector3(-6.3f,1.18f,-2.8f),new Vector2(.72f,.54f),45,true);
        Framed("本日の番組表","KinseiAtelier/broadcast",new Vector3(-1.99f,1.65f,-8.34f),new Vector2(.64f,.72f),0,false);
        Framed("金星の専属歌手","KinseiAtelier/chanteuse",new Vector3(3.1f,1.65f,-8.38f),new Vector2(.73f,.98f),0,false);
        Framed("漆絵の椿","KinseiAtelier/camellia",new Vector3(4.1f,4.75f,8.76f),new Vector2(2.25f,1.69f),0,false);
        Framed("系列店の琺瑯看板","KinseiAtelier/lotus-sign",new Vector3(5.5f,2.2f,-8.47f),new Vector2(2.85f,.974f),0,false);
        TablePrints();
    }

    Material Surface(Color color,float metallic,float sheen)
    {
        var m=new Material(Shader.Find("Standard"));m.color=color;
        m.SetFloat("_Metallic",metallic);m.SetFloat("_Glossiness",sheen);return m;
    }
    Transform Shape(PrimitiveType shape,string name,Transform parent,Vector3 at,Vector3 size,Material material)
    {
        var go=GameObject.CreatePrimitive(shape);go.name=name;go.transform.SetParent(parent,false);
        go.transform.localPosition=at;go.transform.localScale=size;go.GetComponent<Renderer>().sharedMaterial=material;
        var collider=go.GetComponent<Collider>();collider.enabled=false;Destroy(collider);return go.transform;
    }
    void Framed(string label,string resource,Vector3 at,Vector2 dims,float yaw,bool broadcast)
    {
        var tex=Resources.Load<Texture2D>(resource);if(tex==null)return;
        var frame=new GameObject(label).transform;frame.SetParent(transform,false);frame.position=at;frame.rotation=Quaternion.Euler(0,yaw,0);
        float depth=broadcast?.12f:.035f;
        Shape(PrimitiveType.Cube,"框",frame,Vector3.zero,new Vector3(dims.x+.048f,dims.y+.048f,depth),metal);
        var art=Surface(Color.white,0,broadcast?.37f:.16f);art.mainTexture=tex;
        if(broadcast){art.EnableKeyword("_EMISSION");art.SetTexture("_EmissionMap",tex);art.SetColor("_EmissionColor",new Color(.54f,.48f,.42f));}
        Shape(PrimitiveType.Quad,"印刷面・管面",frame,new Vector3(0,0,-depth*.52f),new Vector3(dims.x,dims.y,1),art);
        if(broadcast) {
            Shape(PrimitiveType.Cube,"卓上中継機の台座",frame,new Vector3(0,-.35f,.015f),new Vector3(.48f,.105f,.29f),lacquer);
            for(int i=0;i<4;i++)Shape(PrimitiveType.Sphere,"選局キー",frame,new Vector3(-.13f+i*.081f,-.299f,-.073f),new Vector3(.04f,.018f,.04f),metal);
        }
    }
    void TablePrints()
    {
        var tex=Resources.Load<Texture2D>("Art/house-print-atlas"); if(tex==null)return;
        for(int i=0;i<3;i++)
        {
            var m=Surface(Color.white,0,.2f);m.mainTexture=tex;
            m.mainTextureScale=new Vector2(.49f,.49f);
            m.mainTextureOffset=new Vector2(i==1?.505f:.005f,i<2?.505f:.005f);
            for(int s=-1;s<=1;s+=2) {
                Vector3 pos=new Vector3(s*6.3f+.19f,.783f,-5.5f+i*2.7f+.12f);
                var item=Shape(PrimitiveType.Quad,"金星の卓上印刷物",transform,pos,Vector3.one*(i==0?.17f:.25f),m);
                item.rotation=Quaternion.Euler(90,s*(i+1)*17,0);
            }
        }
    }
}

