using UnityEngine;

public sealed partial class KinseiWorld
{
    void BuildHallServiceDoor()
    {
        // The opening sits under the terrace, immediately left of the 1.9 m stair.
        // All parts are rendered scenery; the existing navigation and aim geometry stays authoritative.
        var root=new GameObject("右奥・従業員通用口").transform;
        root.SetParent(transform,false);
        root.localPosition=new Vector3(4.13f,0,5.99f);
        foreach(int side in new[]{-1,1})
        {
            Box("通用口・方立",new Vector3(side*.72f,1.17f,0),new Vector3(.105f,2.34f,.19f),dark,false,root);
            Box("通用口・磨いた框",new Vector3(side*.667f,1.16f,-.086f),new Vector3(.026f,2.32f,.035f),brass,false,root);
        }
        Box("通用口・鴨居",new Vector3(0,2.28f,0),new Vector3(1.53f,.15f,.19f),dark,false,root);
        // Swing the right-hand door inward. A short, lit plaster return makes the opening read in depth.
        var hinge=new GameObject("片開き扉の吊元").transform;hinge.SetParent(root,false);
        hinge.localPosition=new Vector3(.658f,0,.065f);hinge.localRotation=Quaternion.Euler(0,61,0);
        Box("半開きの職員扉",new Vector3(-.60f,1.12f,0),new Vector3(1.20f,2.16f,.060f),wood,false,hinge);
        Box("腰下の蹴板",new Vector3(-.60f,.22f,-.036f),new Vector3(1.11f,.32f,.013f),dark,false,hinge);
        Box("通用口の押板",new Vector3(-1.04f,1.10f,-.041f),new Vector3(.095f,.28f,.017f),brass,false,hinge);
        Box("内廊下の袖壁",new Vector3(-.735f,1.14f,.53f),new Vector3(.095f,2.28f,1.08f),cream,false,root);
        Box("内廊下の片引き窓",new Vector3(-.31f,1.58f,1.26f),new Vector3(.62f,.55f,.06f),wood,false,root);
        Box("台所の型板硝子",new Vector3(-.31f,1.58f,1.215f),new Vector3(.53f,.46f,.025f),glow,false,root);
        Box("角形出口灯の金属箱",new Vector3(0,2.64f,-.044f),new Vector3(1.07f,.39f,.22f),dark,false,root);
        Box("角形出口灯の乳白面",new Vector3(0,2.64f,-.17f),new Vector3(.94f,.26f,.048f),cyan,false,root);
        Box("出口灯の吊金具",new Vector3(0,2.86f,-.045f),new Vector3(.072f,.10f,.065f),brass,false,root);
        var bounce=LightAt("通用口の内明かり",root.localPosition+new Vector3(-.37f,1.86f,.64f),new Color(1,.78f,.49f),1.77f,3.55f);
        bounce.renderMode=LightRenderMode.ForceVertex;
    }
}
