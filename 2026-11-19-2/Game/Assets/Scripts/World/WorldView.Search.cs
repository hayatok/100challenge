using UnityEngine;

namespace Evac
{
    public sealed partial class WorldView
    {
        GameObject furnishedSearchDistrict;
        internal void ShowSearchFurniture(GameSim simulation)
        {
            if(!district || district==furnishedSearchDistrict || !simulation.HasSearch)return;
            furnishedSearchDistrict=district;
            for(int i=0;i<3;i++){
                Vector3 point=simulation.SearchPoint(i);
                var table=Place(i==1?"searchRadio":"searchRecords",point+Vector3.right*.86f);
                table.transform.localRotation=Quaternion.Euler(0,i==1?90:-12,0);
            }
            Place("searchAid",simulation.SearchPoint(8)+Vector3.right*1.2f);
        }
    }
}
