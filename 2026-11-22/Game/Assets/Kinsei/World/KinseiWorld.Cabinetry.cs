using System.Collections.Generic;
using UnityEngine;

public sealed partial class KinseiWorld
{
    // Grain runs along image U. The room's original shared wood material tiles U twice.
    const float VeneerLength=.80f, VeneerWidth=.62f, HalfJoint=.0011f, JointDepth=.0015f;
    readonly List<MeshFilter> veneerSources=new List<MeshFilter>();

    void VeneerBox(string name,Vector3 centre,Vector3 dimensions,Material material,bool solid,Transform parent=null,
        bool upright=false)
    {
        var part=Box(name,centre,dimensions,material,solid,parent);
        part.transform.localScale=Vector3.one;
        var collider=part.GetComponent<BoxCollider>();
        if(collider)collider.size=dimensions;
        var filter=part.GetComponent<MeshFilter>();
        filter.sharedMesh=new VeneerPanels().Build(dimensions,upright,centre,material.mainTextureScale);
        veneerSources.Add(filter);
    }

    // BatchArchitecture has copied these vertices into its material mesh. Keep every collider and transform.
    void ReleaseVeneerSources()
    {
        foreach(var filter in veneerSources)
        {
            var source=filter.sharedMesh;filter.sharedMesh=null;Destroy(source);
        }
        veneerSources.Clear();
    }

    sealed class VeneerPanels
    {
        readonly List<Vector3> positions=new List<Vector3>();
        readonly List<Vector2> texcoords=new List<Vector2>();
        readonly List<int> indices=new List<int>();
        Vector2 tiling;
        int identity;

        public Mesh Build(Vector3 size,bool upright,Vector3 centre,Vector2 scale)
        {
            tiling=scale;
            identity=Mathf.RoundToInt(centre.x*31+centre.y*57+centre.z*113);
            Vector3 x=Vector3.right,y=Vector3.up,z=Vector3.forward;
            Face(z*(size.z*.5f),x,y,size.x,size.y,upright,1);
            Face(-z*(size.z*.5f),-x,y,size.x,size.y,upright,2);
            Face(x*(size.x*.5f),-z,y,size.z,size.y,upright,3);
            Face(-x*(size.x*.5f),z,y,size.z,size.y,upright,4);
            // Long tools and stair nosings run across X; a narrow Z-long bar runs end to end.
            Face(y*(size.y*.5f),x,-z,size.x,size.z,size.z>size.x,5);
            Face(-y*(size.y*.5f),x,z,size.x,size.z,size.z>size.x,6);
            var mesh=new Mesh{name="Walnut / cut veneer"};
            mesh.SetVertices(positions);mesh.SetUVs(0,texcoords);mesh.SetTriangles(indices,0);
            mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();
            return mesh;
        }

        void Face(Vector3 centre,Vector3 across,Vector3 up,float width,float height,bool vertical,int face)
        {
            // Use consecutive parts of one leaf. Tall sheets on walls and long boards on treads.
            int columns=Mathf.CeilToInt(width/(vertical?.56f:2.42f));
            int rows=Mathf.CeilToInt(height/(vertical?2.42f:.56f));
            float w=width/columns,h=height/rows;
            Vector3 n=Vector3.Cross(across,up);
            for(int j=0;j<rows;j++)for(int i=0;i<columns;i++)
            {
                Vector3 origin=centre+across*(-width*.5f+i*w)+up*(-height*.5f+j*h);
                int seed=identity+i*37+j*71+face*89;
                Vector2 start=new Vector2(Mathf.Repeat(seed*.61803f,1),Mathf.Repeat(seed*.41421f,1));
                bool flip=((i+j+face)&1)!=0;
                Vector3 P(float u,float v,float d)=>origin+across*u+up*v-n*d;
                Vector2 UV(float u,float v)
                {
                    float g=vertical?v:u,c=vertical?u:v;
                    return new Vector2((start.x+g/VeneerLength)/tiling.x,
                        (start.y+(flip?-c:c)/VeneerWidth)/tiling.y);
                }
                void Quad(float ax,float ay,float ad,float bx,float by,float bd,
                    float cx,float cy,float cd,float dx,float dy,float dd)
                {
                    int k=positions.Count;
                    positions.Add(P(ax,ay,ad));positions.Add(P(bx,by,bd));
                    positions.Add(P(cx,cy,cd));positions.Add(P(dx,dy,dd));
                    texcoords.Add(UV(ax,ay));texcoords.Add(UV(bx,by));texcoords.Add(UV(cx,cy));texcoords.Add(UV(dx,dy));
                    indices.Add(k);indices.Add(k+1);indices.Add(k+2);indices.Add(k);indices.Add(k+2);indices.Add(k+3);
                }
                if(columns==1 && rows==1){Quad(0,0,0,w,0,0,w,h,0,0,h,0);continue;}
                // Stop the recess 1.1 mm before exterior edges. Adjacent panels agree at every
                // seam vertex; the outermost perimeter stays flush with the neighbouring box face.
                float Coord(int k,float extent)=>k==0?0:k==1?HalfJoint:k==2?extent-HalfJoint:extent;
                float Depth(int a,int b)
                {
                    bool left=a==0,right=a==3,low=b==0,high=b==3;
                    if((left && i==0)||(right && i==columns-1)||(low && j==0)||(high && j==rows-1))return 0;
                    return left || right || low || high?JointDepth:0;
                }
                for(int v=0;v<3;v++)for(int u=0;u<3;u++)
                {
                    float x0=Coord(u,w),x1=Coord(u+1,w),y0=Coord(v,h),y1=Coord(v+1,h);
                    Quad(x0,y0,Depth(u,v),x1,y0,Depth(u+1,v),
                        x1,y1,Depth(u+1,v+1),x0,y1,Depth(u,v+1));
                }
            }
        }
    }
}
