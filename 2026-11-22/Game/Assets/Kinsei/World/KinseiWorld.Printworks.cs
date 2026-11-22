using UnityEngine;

public sealed partial class KinseiWorld
{
    Material[] sleevePrints, bottlePrints, stationPrints;
    Transform meterNeedle;

    Material[] PrintCells(string sheet,int columns,int rows,bool cutout=false)
    {
        Texture2D atlas=Resources.Load<Texture2D>("KinseiPrintworks/"+sheet);
        var cells=new Material[columns*rows];
        if(!atlas)return cells;
        Vector2 inset=new Vector2(8f/atlas.width,8f/atlas.height);
        for(int k=0;k<cells.Length;k++){
            var ink=Mat(sheet+" "+(k+1),"#FFFFFF",0,.21f);
            ink.mainTexture=atlas;
            ink.mainTextureScale=new Vector2(1f/columns,1f/rows)-2*inset;
            ink.mainTextureOffset=new Vector2((k%columns)/(float)columns,1-(k/columns+1)/(float)rows)+inset;
            if(cutout){
                ink.SetOverrideTag("RenderType","TransparentCutout");ink.SetFloat("_Mode",1);
                ink.SetFloat("_Cutoff",.40f);ink.EnableKeyword("_ALPHATEST_ON");
                ink.renderQueue=(int)UnityEngine.Rendering.RenderQueue.AlphaTest;
            }
            cells[k]=ink;
        }
        return cells;
    }

    void PrintedFace(Transform room,string label,Material ink,Vector3 at,Vector2 size,Quaternion rotation)
    {
        if(!ink)return;
        var face=Part(label,PrimitiveType.Quad,at,new Vector3(size.x,size.y,1),ink,false,room);
        face.transform.localRotation=rotation;
    }

    void DressRecordWall(Transform room)
    {
        sleevePrints=PrintCells("Sleeves",4,2);
        for(int shelf=0;shelf<2;shelf++){
            float h=1.46f+shelf*.67f;
            Box("Front-facing album shelf",new Vector3(.1f,h,-5.78f),new Vector3(3.44f,.045f,.24f),wood,false,room);
            Rail(new Vector3(-1.56f,h+.11f,-5.66f),new Vector3(1.76f,h+.11f,-5.66f),.009f,brass,room);
            for(int n=0;n<4;n++){
                var position=new Vector3(-1.20f+n*.88f,h+.205f,-5.80f);
                var jacket=Box("Display LP jacket",position,new Vector3(.37f,.37f,.023f),cream,false,room).transform;
                PrintedFace(room,"Printed record jacket",sleevePrints[shelf*4+n],jacket.localPosition+Vector3.forward*.014f,
                    new Vector2(.368f,.368f),Quaternion.Euler(0,180,0));
            }
        }
    }

    void BottleLabel(Vector3 at,int type,float height)
    {
        if(bottlePrints==null)bottlePrints=PrintCells("Bottles",2,2,true);
        if(!bottlePrints[type])return;
        const int segments=14;
        var v=new Vector3[(segments+1)*2];var uv=new Vector2[v.Length];
        var triangles=new int[segments*6];
        for(int i=0;i<=segments;i++){
            float u=i/(float)segments,angle=(u-.5f)*2.02f;
            var p=new Vector3(Mathf.Sin(angle)*.059f,0,-Mathf.Cos(angle)*.059f);
            v[2*i]=p-Vector3.up*height*.5f;v[2*i+1]=p+Vector3.up*height*.5f;
            uv[2*i]=new Vector2(u,0);uv[2*i+1]=new Vector2(u,1);
            if(i==segments)continue;
            int a=i*2,k=i*6;
            triangles[k]=a;triangles[k+1]=a+1;triangles[k+2]=a+2;
            triangles[k+3]=a+2;triangles[k+4]=a+1;triangles[k+5]=a+3;
        }
        var mesh=new Mesh{name="Printed bottle band",vertices=v,uv=uv,triangles=triangles};
        mesh.RecalculateNormals();mesh.RecalculateTangents();
        var label=Surface(mesh.name,mesh,bottlePrints[type],transform);
        label.transform.localPosition=at;
    }

    void DressExchangePrints(Transform room)
    {
        stationPrints=PrintCells("Station",2,2);
        var upright=Quaternion.Euler(0,180,0);
        var meter=new Vector3(.64f,1.42f,-4.31f);
        Cushion("Meter housing",meter,new Vector3(.60f,.35f,.27f),dark,room);
        PrintedFace(room,"VU scale plate",stationPrints[0],meter+Vector3.forward*.143f,new Vector2(.48f,.24f),upright);
        meterNeedle=new GameObject("音楽回線のVU指針").transform;
        meterNeedle.SetParent(room,false);meterNeedle.localPosition=meter+new Vector3(0,-.087f,.151f);
        var pointer=Box("Moving meter needle",new Vector3(0,.067f,0),new Vector3(.006f,.134f,.003f),dark,false,meterNeedle);Moving(pointer);
        PrintedFace(room,"Local line ticket",stationPrints[1],new Vector3(-3.78f,1.57f,-4.895f),new Vector2(.79f,.395f),upright);
        PrintedFace(room,"Afternoon programme",stationPrints[2],new Vector3(2.52f,1.64f,-5.90f),new Vector2(1.12f,.56f),upright);
        PrintedFace(room,"Centennial kept ticket",stationPrints[3],new Vector3(1.62f,1.146f,-4.09f),new Vector2(.30f,.15f),Quaternion.Euler(90,0,0));
    }

    public void SetProgrammeLevel(float value)
    {
        if(meterNeedle)meterNeedle.localRotation=Quaternion.Euler(0,0,Mathf.Lerp(-49,48,value));
    }
}
