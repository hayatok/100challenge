using UnityEngine;

public sealed partial class KinseiWorld
{
    void BuildBathLockers()
    {
        var origin=new Vector3(-41.05f,.30f,-16.46f);
        var casework=new GameObject("桐の下足箱").transform;
        casework.SetParent(transform,false);
        casework.localPosition=origin;
        const float bay=.325f,row=.253f,front=.178f;
        const int columns=4,rows=4;
        float width=columns*bay,height=rows*row;
        VeneerBox("下足箱の裏板",new Vector3(0,height*.5f,-.137f),new Vector3(width+.035f,height+.024f,.036f),wood,false,casework,true);
        for(int i=0;i<=columns;i++)
            VeneerBox("縦仕切り",new Vector3((i-2)*bay,height*.5f,.01f),new Vector3(.020f,height,.317f),wood,false,casework,true);
        for(int i=0;i<=rows;i++)
            VeneerBox("上がり框側の棚板",new Vector3(0,i*row,.01f),new Vector3(width+.040f,.019f,.326f),wood,false,casework);
        BathCollider("下足箱本体",origin+new Vector3(0,height*.5f,.02f),new Vector3(width+.04f,height,.33f));
        for(int r=0;r<rows;r++)for(int c=0;c<columns;c++){
            int number=(rows-1-r)*columns+c+1;
            var hinge=new GameObject("下足入れ "+number).transform;
            hinge.SetParent(casework,false);
            hinge.localPosition=new Vector3((c-2)*bay+.014f,r*row+row*.5f,front);
            bool ajar=number==7 || number==14;
            hinge.localRotation=Quaternion.Euler(0,ajar?(number==7?-49:-28):0,0);
            VeneerBox("小扉",new Vector3(.143f,0,0),new Vector3(.289f,.223f,.023f),wood,false,hinge,true);
            Box("差し込み錠の受け",new Vector3(.229f,.010f,.016f),new Vector3(.068f,.093f,.013f),brass,false,hinge);
            Box("角穴",new Vector3(.229f,.026f,.025f),new Vector3(.030f,.010f,.004f),dark,false,hinge);
            if(!ajar){
                Box("取り外せる木札",new Vector3(.229f,-.003f,.027f),new Vector3(.040f,.049f,.007f),cream,false,hinge);
                Text(number.ToString("00"),hinge.TransformPoint(new Vector3(.229f,-.003f,.032f)),.034f,dark,180);
            }else{
                float x=(c-1.5f)*bay,y=r*row+.025f;
                foreach(float side in new[]{-.067f,.067f}){
                    var sole=Box("草履の底",new Vector3(x+side,y,.038f),new Vector3(.090f,.016f,.17f),cream,false,casework);
                    sole.transform.localRotation=Quaternion.Euler(0,side*60,0);
                    Box("草履の鼻緒",new Vector3(x+side,y+.018f,.073f),new Vector3(.076f,.019f,.029f),dark,false,casework);
                }
            }
        }
    }
}
