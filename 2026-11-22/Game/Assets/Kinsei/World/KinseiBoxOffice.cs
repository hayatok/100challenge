using UnityEngine;

public sealed class KinseiBoxOffice : MonoBehaviour
{
    public static readonly Vector3 Counter = new Vector3(-2.05f, 0, -6.35f);
    GameObject receipt;
    Transform ticketLever, firstTicket;
    public Vector3 LeverGrip => ticketLever.TransformPoint(new Vector3(.115f,-.018f,0));
    Material wood, brass, ivory, register;

    public void Build()
    {
        wood=new Material(Shader.Find("Standard")){color=new Color(.37f,.24f,.16f)};
        wood.mainTexture=Resources.Load<Texture2D>("KinseiSurfaces/smoked_walnut_veneer_Diffuse");
        brass=new Material(Shader.Find("Standard")){color=new Color(.63f,.45f,.21f)};
        brass.SetFloat("_Metallic",.7f);brass.SetFloat("_Glossiness",.56f);
        ivory=new Material(Shader.Find("Standard")){color=new Color(.83f,.78f,.64f)};
        register=new Material(Shader.Find("Standard")){color=new Color(.055f,.105f,.095f)};
        var counter=new GameObject("金星の帳場").transform;
        counter.SetParent(transform,false);
        counter.localPosition=Counter+new Vector3(0,0,.72f);
        Piece(counter,"帳場の板壁",new Vector3(0,.48f,0),new Vector3(1.23f,.96f,.56f),wood,true);
        Piece(counter,"真鍮を巻いた天板",new Vector3(0,.966f,0),new Vector3(1.30f,.045f,.62f),brass);
        Piece(counter,"レジの塗装鋳物",new Vector3(-.26f,1.09f,.03f),new Vector3(.44f,.21f,.31f),register);
        Piece(counter,"勘定窓",new Vector3(-.26f,1.235f,.13f),new Vector3(.36f,.16f,.11f),register);
        for(int row=0;row<2;row++)for(int key=0;key<5;key++)
            Piece(counter,"象牙色のレジキー",new Vector3(-.41f+key*.067f,1.205f,-.087f+row*.07f),new Vector3(.044f,.021f,.046f),ivory);
        var paper=new Material(Shader.Find("Standard")){color=Color.white,mainTexture=Resources.Load<Texture2D>("Art/house-print-atlas")};
        paper.mainTextureScale=new Vector2(.484f,.484f);paper.mainTextureOffset=new Vector2(.008f,.008f);
        var folio=Piece(counter,"革張りの伝票台",new Vector3(.263f,1.007f,-.035f),new Vector3(.36f,.027f,.43f),register);
        receipt=GameObject.CreatePrimitive(PrimitiveType.Quad);
        receipt.name="今夜の売上伝票";receipt.transform.SetParent(counter,false);
        receipt.transform.localPosition=folio.localPosition+Vector3.up*.018f;
        receipt.transform.localRotation=Quaternion.Euler(90,0,0);receipt.transform.localScale=new Vector3(.30f,.35f,1);
        receipt.GetComponent<Renderer>().sharedMaterial=paper;receipt.GetComponent<Collider>().enabled=false;
        Destroy(receipt.GetComponent<Collider>());
        Piece(counter,"紙留めのばね金具",new Vector3(.263f,1.034f,.13f),new Vector3(.16f,.016f,.035f),brass);
        var press=Piece(counter,"入場券の手動印字機",new Vector3(.38f,1.07f,-.16f),new Vector3(.24f,.15f,.17f),register);
        ticketLever=new GameObject("印字レバーの支点").transform;
        ticketLever.SetParent(counter,false);ticketLever.localPosition=press.localPosition+new Vector3(.107f,.079f,0);
        Piece(ticketLever,"印字レバー",new Vector3(.06f,-.009f,0),new Vector3(.12f,.022f,.026f),brass);
        Piece(ticketLever,"丸い握り",new Vector3(.115f,-.018f,0),new Vector3(.046f,.034f,.047f),register);
        firstTicket=new GameObject("金星興行　一番券").transform;firstTicket.SetParent(counter,false);
        firstTicket.localPosition=new Vector3(.38f,1.09f,-.244f);
        Piece(firstTicket,"厚紙の入場券",new Vector3(0,0,.062f),new Vector3(.087f,.0018f,.125f),ivory);
        var ink=new Material(Shader.Find("Standard")){mainTexture=Resources.Load<Texture2D>("KinseiPrintworks/FirstTicket")};
        ink.SetFloat("_Glossiness",.18f);
        var print=GameObject.CreatePrimitive(PrimitiveType.Quad);
        print.name="一番券の通し番号";print.transform.SetParent(firstTicket,false);
        print.transform.localPosition=new Vector3(0,.0013f,.062f);
        print.transform.localRotation=Quaternion.Euler(90,180,0);print.transform.localScale=new Vector3(.086f,.123f,1);
        print.GetComponent<Renderer>().sharedMaterial=ink;
        var printCollider=print.GetComponent<Collider>();printCollider.enabled=false;Destroy(printCollider);
        SetTicketPress(0);
    }

    Transform Piece(Transform parent,string label,Vector3 at,Vector3 size,Material material,bool solid=false)
    {
        var go=GameObject.CreatePrimitive(PrimitiveType.Cube);
        go.name=label;go.transform.SetParent(parent,false);go.transform.localPosition=at;go.transform.localScale=size;
        go.GetComponent<Renderer>().sharedMaterial=material;
        if(!solid){var collider=go.GetComponent<Collider>();collider.enabled=false;Destroy(collider);}
        return go.transform;
    }
    public void SetCollected(bool collected) { if(receipt)receipt.SetActive(!collected); }
    public void SetTicketPress(float seconds)
    {
        float down=Mathf.SmoothStep(0,1,Mathf.InverseLerp(.55f,1.15f,seconds));
        float release=Mathf.SmoothStep(0,1,Mathf.InverseLerp(1.36f,1.82f,seconds));
        ticketLever.localRotation=Quaternion.Euler(0,0,24-50*(down-release));
        float feed=Mathf.SmoothStep(0,1,Mathf.InverseLerp(.84f,1.64f,seconds));
        firstTicket.gameObject.SetActive(feed>0);
        firstTicket.localPosition=new Vector3(.38f,1.09f,-.244f-.126f*feed);
    }
}
