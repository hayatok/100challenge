using UnityEngine;

public sealed partial class KinseiSession
{
    enum ShopView { None, Coffee, Records, Operator, Meter, Marquee, Wardrobe }
    ShopView shopView;

    ShopView NearbyCounter()
    {
        if(command || phase!=Phase.Arrival || OnAir || player==null)return ShopView.None;
        Vector3 at=player.Position;
        if(!finale && at.x> -12 && at.x< -10.18f && Mathf.Abs(at.z+2.43f)<1.25f && at.y<.5f)return ShopView.Wardrobe;
        if(at.x>3.5f && at.x<7.6f && at.z> -12.1f && at.z< -8.60f)return ShopView.Marquee;
        if(at.z> -16.25f || at.z< -19.8f || at.y> .85f)return ShopView.None;
        if(Mathf.Abs(at.x+16f)<2.35f)return ShopView.Coffee;
        if(Mathf.Abs(at.x)<2.35f)return ShopView.Records;
        if(Mathf.Abs(at.x-16f)<2.35f)return at.x<15.8f?ShopView.Operator:ShopView.Meter;
        return ShopView.None;
    }

    string ShopViewLabel(ShopView view)
    {
        switch(view) {
            case ShopView.Coffee:return "ロータスの仕事台";
            case ShopView.Records:return "針音堂の新譜棚";
            case ShopView.Operator:return "村瀬の調整卓";
            case ShopView.Marquee:return "金星の街頭テレビ";
            case ShopView.Wardrobe:return "歌手の写真と衣裳札";
            default:return "音楽回線のVU計";
        }
    }

    void ShopViewInput()
    {
        if(Input.GetKeyDown(KeyCode.C)) {
            var next=shopView==ShopView.None?NearbyCounter():ShopView.None;
            if(next==shopView)return;
            shopView=next;snapCamera=true;Mark("shop-view-"+shopView);
        } else if(shopView!=ShopView.None && (Input.GetAxisRaw("Horizontal")!=0 || Input.GetAxisRaw("Vertical")!=0 ||
            Input.GetKeyDown(KeyCode.E) || Input.GetMouseButtonDown(1))) {
            shopView=ShopView.None;snapCamera=true;
        }
    }

    void FrameCounter(out Vector3 eye,out Vector3 focus)
    {
        switch(shopView) {
            case ShopView.Coffee:
                eye=new Vector3(-16.08f,1.62f,-17.86f);focus=new Vector3(-17.06f,1.39f,-18.88f);break;
            case ShopView.Records:
                eye=new Vector3(.10f,1.92f,-17.45f);focus=new Vector3(.10f,1.98f,-19.80f);break;
            case ShopView.Operator:
                eye=new Vector3(16.07f,1.58f,-18.64f);focus=new Vector3(14.98f,1.39f,-18.88f);break;
            case ShopView.Marquee:
                eye=new Vector3(5.46f,2.0f,-10.60f);focus=new Vector3(5.5f,2.08f,-8.83f);break;
            case ShopView.Wardrobe:
                eye=new Vector3(-10.16f,1.48f,-2.48f);focus=new Vector3(-9.21f,1.50f,-2.43f);break;
            default:
                eye=new Vector3(16.58f,1.48f,-17.68f);focus=new Vector3(16.64f,1.41f,-18.29f);break;
        }
    }
}
