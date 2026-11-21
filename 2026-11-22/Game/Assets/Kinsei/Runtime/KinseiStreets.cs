using UnityEngine;

public sealed partial class KinseiSession
{
    bool hasCoffeeTickets, coffeeUsed, hasRecord, nominatedSeat, reservedLine, playedRecord;
    static readonly string[] addresses={"純喫茶ロータス","貸レコード針音堂","共同送像所"};

    void ResetStreets()
    {
        hasCoffeeTickets=coffeeUsed=hasRecord=nominatedSeat=reservedLine=playedRecord=false;
        neighbours.ResetNight();
    }

    static Vector3 StreetBounds(Vector3 point)
    {
        point.z=Mathf.Clamp(point.z,-20.5f,8.55f);
        float sideOver=Mathf.Abs(point.x)-8.62f;
        if(sideOver>0 && point.z> -8.07f && point.z+8.07f<sideOver)
            point.z=-8.07f;
        float side=point.z> -8.07f?8.62f:21.6f;
        point.x=Mathf.Clamp(point.x,-side,side);
        return point;
    }

    bool StreetContact(out int shop,out string words)
    {
        shop=-1;words="";
        if(player.Position.z> -9.7f || player.Position.y>1)return false;
        return neighbours.TryInteract(player.Position,2.65f,out shop,out words);
    }

    string StreetVerb(int shop,string words)
    {
        if(shop==0 && !hasCoffeeTickets)return "澄子から夜食券を預かる";
        if(shop==0 && hasRecord && !nominatedSeat)return "常連のリクエストを聞く";
        if(shop==1 && !hasRecord)return "兵藤から金星の試聴盤を借りる";
        if(shop==2 && hasRecord && !reservedLine)return "試聴盤を四十軒へ送る";
        int end=words.IndexOf('「');
        return (end>0?words.Substring(0,end):"近くの人")+"と話す";
    }

    void VisitShop(int shop,string words)
    {
        if(shop==0 && !hasCoffeeTickets){
            hasCoffeeTickets=true;
            Say("澄子「これで夜食を食べておいで」　真壁の体力が55を切ると一度だけ24回復。",5);
            Mark("lotus-tickets");
        } else if(shop==0 && hasRecord && !nominatedSeat) {
            nominatedSeat=true;
            Say("澄子「最初の客席、うちにちょうだい。堺の吹き手が待ってる」",5);
            Mark("lotus-request");
        } else if(shop==1 && !hasRecord) {
            hasRecord=true;sound.Cue("door");
            Say("兵藤「うちの試聴盤や。送像所へ頼めば、兄貴も最後の一曲は待つ」",5);
            Mark("needle-record");
        } else if(shop==2 && hasRecord && !reservedLine) {
            reservedLine=true;escapeTime+=8;
            playedRecord=nominatedSeat;
            Say(playedRecord?"村瀬「ロータスのリクエストやね。出番が来たら梶の席にも先につなぐ」":"村瀬「四十軒、音が来たで。金星にもう一曲、八秒ぶんお願いした」",5);
            Mark("relay-record-"+(playedRecord?"requested":"broadcast"));
        } else if(shop==2 && !hasRecord)Say("村瀬「針音堂で試聴盤を借りて。運んでくれたら、こっちから全店に送れる」",5);
        else Say(words,4.3f);
        sound.Cue("dial");
    }

    void OfferSupper()
    {
        if(!hasCoffeeTickets || coffeeUsed || player.hp<=0 || player.hp>=55)return;
        coffeeUsed=true;player.hp=Mathf.Min(player.maxHp,player.hp+24);
        Say("真壁が澄子の夜食を取った。体力が24戻った。",3);Mark("lotus-recovery");
    }

    void DrawAddresses()
    {
        if(!command || phase!=Phase.Arrival)return;
        for(int i=0;i<3;i++){
            Vector3 at=new Vector3((i-1)*16f,2.1f,-14.4f);
            var point=cam.WorldToViewportPoint(at);
            if(point.x<.06f || point.x>.94f || point.y<.28f || point.y>.83f)continue;
            float x=point.x*hudW,y=(1-point.y)*hudH;
            Rect sign=new Rect(x-94,y,188,25);
            Block(sign,ink);Letter(sign,addresses[i]+(neighbours.IsOpen(i)?"　営業中":"　外出中"),14,gold,false,TextAnchor.MiddleCenter);
        }
    }
}
