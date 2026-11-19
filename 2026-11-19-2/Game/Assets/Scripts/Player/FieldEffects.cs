using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed class FieldEffects : MonoBehaviour
    {
        struct Mote { public Vector3 p,v; public float life,span,size,stretch,gravity,growth; public Color color; }
        readonly Mote[] motes=new Mote[120];
        readonly List<Vector3> points=new List<Vector3>(480);
        readonly List<Vector2> uv=new List<Vector2>(480);
        readonly List<Color> colors=new List<Color>(480);
        readonly List<int> indices=new List<int>(720);
        static readonly Vector2[] Corners={new Vector2(-1,-1),new Vector2(-1,1),new Vector2(1,1),new Vector2(1,-1)};
        int cursor;
        Material ink;
        Mesh mesh;
        Camera eye;
        GameSession game;
        void Awake()
        {
            ink=new Material(Resources.Load<Shader>("Field/Afterglow"));
            mesh=new Mesh {name="Field effects"};mesh.MarkDynamic();
            game=GetComponent<GameSession>();eye=Camera.main;
        }
        void Add(Vector3 p,Vector3 v,float seconds,float size,Color color,float stretch=0,float gravity=.2f,float growth=0)
        {
            motes[cursor]=new Mote{p=p,v=v,life=seconds,span=seconds,size=size,color=color,stretch=stretch,gravity=gravity,growth=growth};
            cursor=(cursor+1)%motes.Length;
        }
        public void Flash(Transform sight,bool reduced)
        {
            var p=sight.position+sight.forward*.89f+sight.right*.108f-sight.up*.135f;
            Add(p,sight.forward*1.8f,.047f,reduced?.035f:.105f,new Color(1,.68f,.26f,.85f));
            if(!reduced)Add(p,sight.forward*.8f,.069f,.043f,new Color(1,.98f,.74f,.8f));
        }
        public void Impact(Vector3 point,int id,bool reduced)
        {
            int n=reduced?2:6;
            for(int i=0;i<n;i++)
            {
                float angle=id*.61f+i*2.39996f;
                var v=new Vector3(Mathf.Cos(angle),.3f+Mathf.Abs(Mathf.Sin(angle*2)),Mathf.Sin(angle))*1.6f;
                Add(point,v,.18f+i*.045f,.027f+i*.003f,new Color(.60f,.42f,.25f,.83f),.055f,.68f);
            }
        }
        public void SquadFlash(Vector3 feet,float yaw,bool reduced)
        {
            var facing=Quaternion.Euler(0,yaw,0);
            Vector3 barrel=feet+facing*new Vector3(.16f,1.23f,.63f);
            Add(barrel,facing*Vector3.forward*2.6f,.072f,reduced?.054f:.095f,new Color(1,.77f,.37f,.92f),.049f,0);
        }
        public void Surface(Vector3 point,Vector3 incoming,bool road,bool reduced)
        {
            Vector3 normal=road?Vector3.up:-incoming;
            int count=reduced?2:8;
            for(int i=0;i<count;i++)
            {
                float angle=(i+cursor)*2.39996f;
                Vector3 spray=normal*(.75f+.16f*i)+new Vector3(Mathf.Sin(angle),.31f,Mathf.Cos(angle))*1.3f;
                if(i<2)
                    Add(point+normal*.018f,spray*.19f,.33f,.06f,new Color(.48f,.54f,.50f,.62f),0,0,.22f);
                else
                    Add(point+normal*.018f,spray,.13f+i*.027f,.018f,road?new Color(.66f,.76f,.74f,.86f):new Color(.94f,.75f,.41f,.9f),.056f,.78f);
            }
        }
        public void ResetField() { System.Array.Clear(motes,0,motes.Length); }
        public void Beacon(Vector3 p,Color tint,int id,bool reduced)
        {
            tint.a=.82f;
            p.y+=.38f;
            Add(p,Vector3.up*.19f,.24f,reduced?.065f:.105f,tint,0,0,.045f);
            if(reduced)return;
            float phase=id+cursor*.71f;
            tint.a=.29f;
            Add(p,new Vector3(.16f*Mathf.Sin(phase)+.25f,.4f,.15f*Mathf.Cos(phase)),.85f,.046f,tint,0,0,.11f);
        }
        void LateUpdate()
        {
            if(!eye || game.Phase!="Playing")return;
            var right=eye.transform.right;var up=eye.transform.up;float dt=Time.deltaTime;
            points.Clear();uv.Clear();colors.Clear();indices.Clear();
            for(int i=0;i<motes.Length;i++)
            {
                var m=motes[i];
                if(m.life<=0)continue;
                m.life-=dt;m.p+=m.v*dt;m.v+=Physics.gravity*(dt*m.gravity);m.size+=m.growth*dt;motes[i]=m;
                if(m.life<=0)continue;
                var c=m.color;c.a*=m.life/m.span;
                int start=points.Count;
                Vector3 across=right*m.size,along=up*m.size;
                if(m.stretch>0)
                {
                    Vector3 projected=m.v-eye.transform.forward*Vector3.Dot(m.v,eye.transform.forward);
                    if(projected.sqrMagnitude>.001f)
                    {
                        along=projected.normalized*(m.size+m.stretch*projected.magnitude);
                        across=Vector3.Cross(eye.transform.forward,projected).normalized*m.size;
                    }
                }
                foreach(var corner in Corners)
                {
                    points.Add(m.p+across*corner.x+along*corner.y);
                    colors.Add(c);uv.Add(corner);
                }
                indices.Add(start);indices.Add(start+1);indices.Add(start+2);
                indices.Add(start);indices.Add(start+2);indices.Add(start+3);
            }
            if(points.Count==0)return;
            mesh.Clear();mesh.SetVertices(points);mesh.SetColors(colors);mesh.SetUVs(0,uv);mesh.SetTriangles(indices,0);
            Graphics.DrawMesh(mesh,Matrix4x4.identity,ink,0,eye);
        }
        void OnDestroy(){if(mesh)Destroy(mesh);if(ink)Destroy(ink);}
    }
}
