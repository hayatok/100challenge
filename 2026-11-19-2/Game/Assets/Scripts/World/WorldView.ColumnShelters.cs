using System;
using UnityEngine;

namespace Evac
{
    internal static class RefugeFurniture
    {
        internal static void Visit(int mission,Action<string,Vector3> place)
        {
            if(mission==0)
            {
                place("columnMarketCanopy",new Vector3(-10,0,-2));
                place("columnMarketControl",new Vector3(-5,0,-3));
            }
            if(mission==5)
            {
                place("columnRailLift",new Vector3(5,0,28.4f));
                place("columnRailService",new Vector3(-8,0,28.4f));
                place("columnFloodControl",new Vector3(-10.1f,0,57));
            }
        }
    }

    public sealed partial class WorldGeometry
    {
        void AddRefugeFurniture(int mission)
        {
            RefugeFurniture.Visit(mission,(asset,p)=>
            {
                if(asset=="columnMarketCanopy")
                {
                    foreach(float x in new[]{-2.1f,2.1f})
                        foreach(float z in new[]{-1.48f,1.48f})Add(p.x+x,p.z+z,.105f,.105f,2.43f);
                    Add(p.x,p.z+1.18f,2.86f,.43f,.63f);
                }
                else if(asset=="columnRailLift" || asset=="columnRailService")
                {
                    Add(p.x-1.32f,p.z,.095f,.14f,2.84f);
                    Add(p.x+1.32f,p.z,.095f,.14f,2.84f);
                }
                else Add(p.x,p.z,.80f,.53f,1.62f);
            });
        }
    }

    public sealed partial class WorldView
    {
        MeshFilter columnSignal;
        GameObject columnWater,stretcher,stretcherArms;
        Material columnWaterMaterial;
        bool lastColumnOpen;
        Mesh columnWaterMesh;

        void BuildRefuges(int route)
        {
            columnSignal=null;columnWater=null;stretcher=null;stretcherArms=null;lastColumnOpen=false;
            RefugeFurniture.Visit(route,(asset,p)=>
            {
                var item=Place(asset,p);
                if(!asset.EndsWith("Control",StringComparison.Ordinal))return;
                var lamp=MakeObject("Control pilot light",GetMesh("signalOff"),item.transform);
                lamp.transform.localPosition=new Vector3(.22f,1.83f,0);
                lamp.transform.localScale=Vector3.one*.68f;
                columnSignal=lamp.GetComponent<MeshFilter>();
            });
            if(route!=5)return;
            if(!columnWaterMaterial)columnWaterMaterial=new Material(Resources.Load<Shader>("World/FloodPassage"));
            if(!columnWaterMesh)
            {
                columnWaterMesh=new Mesh{name="Flooded lift approach"};
                columnWaterMesh.vertices=new[]{new Vector3(-2.8f,0,-11),new Vector3(-2.8f,0,11),
                    new Vector3(2.8f,0,11),new Vector3(2.8f,0,-11)};
                columnWaterMesh.uv=new[]{Vector2.zero,Vector2.up,Vector2.one,Vector2.right};
                columnWaterMesh.triangles=new[]{0,1,2,0,2,3};
                columnWaterMesh.RecalculateBounds();
            }
            columnWater=MakeObject("Floodwater at the lift",columnWaterMesh,district.transform);
            columnWater.GetComponent<MeshRenderer>().sharedMaterial=columnWaterMaterial;
            columnWater.transform.localPosition=new Vector3(5,.015f,36.7f);
        }

        internal void DrawStretcher(Unit patient,float direction,bool pushing)
        {
            if(patient==null)
            {
                if(stretcher && stretcher.activeSelf)stretcher.SetActive(false);
                return;
            }
            if(!stretcher)
            {
                stretcher=Place("columnStretcher",patient.pos);
                stretcherArms=MakeObject("Hands on push handles",GetMesh("columnStretcherArms"),stretcher.transform);
            }
            if(!stretcher.activeSelf)stretcher.SetActive(true);
            if(stretcherArms.activeSelf!=pushing)stretcherArms.SetActive(pushing);
            stretcher.transform.SetPositionAndRotation(patient.pos,Quaternion.Euler(0,direction,0));
        }

        void ReleaseRefugeAssets()
        {
            if(columnWaterMesh)ReleaseOwned(columnWaterMesh);
            if(columnWaterMaterial)ReleaseOwned(columnWaterMaterial);
        }

        internal void DrawColumnShelters(GameSim field,int mission)
        {
            if(columnSignal)
            {
                bool open=field.ColumnsActive && field.ColumnControlOpen(mission==5?1:0);
                if(open!=lastColumnOpen)
                {
                    lastColumnOpen=open;columnSignal.sharedMesh=GetMesh(open?"signalOn":"signalOff");
                }
            }
            if(!columnWater)return;
            var water=columnWater.transform;
            float depth=Mathf.Clamp01(field.Water);
            // The same pump state controls the visual depth and column route eligibility.
            water.localPosition=new Vector3(5,.012f+depth*.29f,36.7f);
            water.localScale=new Vector3(.48f+depth*.52f,1,.34f+depth*.66f);
            columnWaterMaterial.SetVector("_Flood",new Vector4(waterClock,depth,(field.PowerMask&1)!=0?1:0,0));
            var pawn=field.Controlled;
            columnWaterMaterial.SetVector("_Boot",pawn==null?new Vector4(2000,2000,0,0):
                new Vector4(pawn.pos.x,pawn.pos.z,pawn.moving?1:0,0));
        }
    }
}
