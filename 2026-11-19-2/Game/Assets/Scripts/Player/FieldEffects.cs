using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed class FieldEffects : MonoBehaviour
    {
        struct Mote { public Vector3 p,v; public float life,span,size; public Color color; }
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
        void Add(Vector3 p,Vector3 v,float seconds,float size,Color color)
        {
            motes[cursor]=new Mote{p=p,v=v,life=seconds,span=seconds,size=size,color=color};
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
                Add(point,v,.18f+i*.045f,.032f+i*.004f,new Color(.86f,.68f,.38f,.74f));
            }
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
                m.life-=dt;m.p+=m.v*dt;m.v+=Physics.gravity*(dt*.2f);motes[i]=m;
                if(m.life<=0)continue;
                var c=m.color;c.a*=m.life/m.span;
                int start=points.Count;
                foreach(var corner in Corners)
                {
                    points.Add(m.p+(right*corner.x+up*corner.y)*m.size);
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
