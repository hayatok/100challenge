param([Parameter(Mandatory)][string]$Project,[Parameter(Mandatory)][string]$Out,[string]$Source)
if(!$Source){$Source="$Project/Game/Assets/Kinsei/World/KinseiWorld.Cabinetry.cs"}
$code=Get-Content -Raw $Source
$geo=$code.Substring($code.IndexOf('    sealed class VeneerPanels'))
$types=@'
using System;
using System.IO;
using System.Collections.Generic;
public struct Vector2 {
 public float x,y; public Vector2(float x,float y){this.x=x;this.y=y;}
}
public struct Vector3 {
 public float x,y,z;public Vector3(float x,float y,float z){this.x=x;this.y=y;this.z=z;}
 public static Vector3 right=>new Vector3(1,0,0);public static Vector3 up=>new Vector3(0,1,0);public static Vector3 forward=>new Vector3(0,0,1);
 public static Vector3 operator +(Vector3 a,Vector3 b)=>new Vector3(a.x+b.x,a.y+b.y,a.z+b.z);
 public static Vector3 operator -(Vector3 a,Vector3 b)=>a+(-b);
 public static Vector3 operator -(Vector3 a)=>new Vector3(-a.x,-a.y,-a.z);
 public static Vector3 operator *(Vector3 a,float k)=>new Vector3(a.x*k,a.y*k,a.z*k);
 public static Vector3 Cross(Vector3 a,Vector3 b)=>new Vector3(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x);
}
public static class Mathf{
 public static int RoundToInt(float x)=>(int)Math.Round(x);public static int CeilToInt(float x)=>(int)Math.Ceiling(x);public static float Repeat(float v,float l)=>v-(float)Math.Floor(v/l)*l;
}
public class Mesh{
 public string name;public List<Vector3> v;public List<Vector2> uv;public List<int> t;
 public void SetVertices(List<Vector3> s){v=s;} public void SetUVs(int n,List<Vector2> s){uv=s;}public void SetTriangles(List<int> s,int n){t=s;}
 public void RecalculateNormals(){}public void RecalculateTangents(){}public void RecalculateBounds(){}
}
public class Probe {
 public static void Run(string dir){
    string[] names={"wall","counter","stair"};Vector3[] sizes={new Vector3(18,6,.25f),new Vector3(4.45f,.98f,.78f),new Vector3(1.9f,1.6f,.37f)};
    for(int i=0;i<3;i++){var m=new VeneerPanels().Build(sizes[i],i!=2,new Vector3(0,0,0),new Vector2(2,1));
    using(var f=new BinaryWriter(File.Create(Path.Combine(dir,names[i]+".bin")))){
     f.Write(m.v.Count);for(int j=0;j<m.v.Count;j++){var v=m.v[j];f.Write(v.x);f.Write(v.y);f.Write(v.z);f.Write(m.uv[j].x);f.Write(m.uv[j].y);}
     f.Write(m.t.Count);foreach(int k in m.t)f.Write(k);}}}
'@
$constants=[regex]::Match($code,'const float VeneerLength=[^;]+;').Value
Add-Type -TypeDefinition ($types+$constants+$geo)
[Probe]::Run($Out)
