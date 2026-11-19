using UnityEngine;

namespace Evac
{
    public sealed partial class WorldView
    {
        Texture2D roomLight;

        void BindRoomLight(Material material,int districtIndex)
        {
            if(!roomLight)
                roomLight=new Texture2D(256,512,TextureFormat.RGBA32,false,true) {
                    wrapMode=TextureWrapMode.Clamp,filterMode=FilterMode.Bilinear,name="Indoor light and contact shadows"
                };
            var asset=Resources.Load<TextAsset>("World/roomLight"+districtIndex);
            roomLight.LoadRawTextureData(asset.bytes);
            roomLight.Apply(false,false);
            material.SetTexture("_RoomLight",roomLight);
            Resources.UnloadAsset(asset);
        }
    }
}
