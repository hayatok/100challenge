using UnityEngine;

public sealed partial class KinseiWorld
{
    Transform masterSleeve;
    GameObject masterDisc;

    void CreateMasterRecord()
    {
        masterSleeve=new GameObject("金星の原盤・見本紙袋").transform;
        masterSleeve.SetParent(transform,false);
        var card=Mat("Uncoated sleeve board","#D6C8A6",0,.14f);
        var print=Mat("Kinsei master sleeve print","#FAF5EB",0,.16f);
        print.mainTexture=Resources.Load<Texture2D>("KinseiDistrictArt/needle-sleeve");
        Moving(Box("Record sleeve spine",Vector3.zero,new Vector3(.309f,.309f,.006f),card,false,masterSleeve));
        foreach(int side in new[]{-1,1}) {
            var cover=Part("Printed sleeve face",PrimitiveType.Quad,new Vector3(0,0,side*.0038f),
                new Vector3(.306f,.306f,1),print,false,masterSleeve);
            cover.transform.localRotation=Quaternion.Euler(0,side<0?0:180,0);Moving(cover);
        }
        var vinyl=Mat("Master lacquer","#161518",.29f,.82f);
        masterDisc=new GameObject("番組の原盤");
        masterDisc.transform.SetParent(transform,false);
        var record=Cylinder("Lacquer record",Vector3.zero,.151f,.004f,vinyl,false,masterDisc.transform);Moving(record);
        var label=Cylinder("Handwritten studio label",Vector3.up*.0025f,.048f,.002f,card,false,masterDisc.transform);Moving(label);
        for(int i=0;i<3;i++){
            float w=.029f-i*.004f;
            Moving(Box("Catalogue lettering",new Vector3(0,.0042f,.013f+i*.004f),new Vector3(w,.001f,.0014f),dark,false,masterDisc.transform));
        }
    }

    public void PutAwayMaster()
    {
        if(!masterSleeve)CreateMasterRecord();
        masterSleeve.SetParent(transform,false);
        masterSleeve.gameObject.SetActive(false);masterDisc.SetActive(false);
    }

    public void SetMasterOnDesk(Vector3 centre,bool spin)
    {
        masterSleeve.SetParent(transform,false);masterSleeve.gameObject.SetActive(true);
        masterSleeve.localPosition=centre+(spin?new Vector3(.36f,-.095f,.019f):Vector3.zero);
        masterSleeve.localRotation=Quaternion.Euler(90,spin?7:-6,0);
        masterDisc.SetActive(spin);
        if(spin)masterDisc.transform.localPosition=centre;
    }

    public void CarryMaster(Transform wrist)
    {
        masterDisc.SetActive(false);masterSleeve.gameObject.SetActive(true);
        masterSleeve.SetParent(wrist,false);
        masterSleeve.localPosition=new Vector3(-.02f,-.15f,-.035f);
        masterSleeve.localRotation=Quaternion.Euler(0,78,9);
    }
}
