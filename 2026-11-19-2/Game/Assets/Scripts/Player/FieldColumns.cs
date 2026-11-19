using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        int followedColumn=-1,routeColumn=-1,routePoints;
        float routeChecked;
        Vector3 routeStart,routeEnd;
        readonly Vector3[] columnRoute=new Vector3[18];

        public void PossessFieldActor(int id)
        {
            var actor=sim.Find(id);
            if(actor!=null && actor.kind==UnitKind.Soldier)Possess(roster.IndexOf(actor));
        }

        public bool ColumnAction(int column,int action)
        {
            if(Phase!="Playing" || !sim.CommandColumn(column,action,SelectedSquad))return false;
            followedColumn=column;
            sound.Signal(sim.Controlled==null?"dispatch":"action");
            return true;
        }

        public void LocateColumn(int column)
        {
            if(!sim.ColumnsActive || column<0 || column>=sim.ColumnCount)return;
            followedColumn=column;
            if(sim.Controlled!=null)return;
            mapCenter=sim.ColumnPosition(column);
            zoom=TouchUI?12:10;
            ShowOrderPin(mapCenter);
        }

        public int PushedColumn
        {
            get
            {
                var pawn=sim.Controlled;
                if(pawn==null || !sim.ColumnsActive)return -1;
                for(int c=0;c<sim.ColumnCount;c++)
                    if(sim.ColumnCarrierId(c)==pawn.id && sim.ColumnCarriedId(c)>=0)return c;
                return -1;
            }
        }

        int NearbyColumn()
        {
            var pawn=sim.Controlled;
            if(pawn==null || !sim.ColumnsActive || sim.ColumnsComplete)return -1;
            int nearest=-1;
            float closest=2.9f*2.9f;
            for(int c=0;c<sim.ColumnCount;c++)
            {
                if(sim.ColumnFinished(c))continue;
                float distance=(sim.ColumnPosition(c)-pawn.pos).sqrMagnitude;
                if(sim.CanCommandColumn(c,4,SelectedSquad))
                    distance=Mathf.Min(distance,(sim.ColumnControlPoint(c)-pawn.pos).sqrMagnitude);
                if(distance<closest){closest=distance;nearest=c;}
            }
            return nearest;
        }

        void ColumnMarkers()
        {
            if(!sim.ColumnsActive || sim.ColumnsComplete)return;
            for(int c=0;c<sim.ColumnCount;c++)
            {
                if(sim.ColumnFinished(c))continue;
                Vector3 lead=sim.ColumnPosition(c);
                if(sim.Controlled!=null && c!=followedColumn && (lead-sim.Controlled.pos).sqrMagnitude>22*22)continue;
                WorldTag(lead+Vector3.up*2.32f,sim.ColumnTitle(c),new Color(.57f,.84f,.78f),true);
                if(c!=followedColumn || sim.ColumnRoute(c)<0)continue;
                var next=sim.ColumnDestination(c);
                if((next-lead).sqrMagnitude<10)continue;
                if(sim.Controlled==null)DrawColumnLeg(c,lead,next);
                WorldTag(next+Vector3.up*1.55f,sim.ColumnNextStop(c),new Color(.91f,.76f,.48f),true);
            }
        }

        void DrawColumnLeg(int column,Vector3 origin,Vector3 goal)
        {
            if(column!=routeColumn || (goal-routeEnd).sqrMagnitude>1 || (origin-routeStart).sqrMagnitude>6 ||
                Time.unscaledTime>=routeChecked+.75f)
            {
                routeColumn=column;routeStart=origin;routeEnd=goal;routeChecked=Time.unscaledTime;
                routePoints=0;
                var last=origin;
                while(routePoints<columnRoute.Length)
                {
                    var next=sim.ColumnNavigationStep(last,goal);
                    if((next-last).sqrMagnitude<.02f)break;
                    columnRoute[routePoints++]=next;
                    if((next-goal).sqrMagnitude<.12f)break;
                    last=next;
                }
            }
            Color tint=sim.ColumnRouteClear(column)?new Color(.24f,.82f,.82f,.83f):new Color(.96f,.58f,.24f,.83f);
            for(int i=0;i<routePoints;i++)RouteSegment(i==0?origin:columnRoute[i-1],columnRoute[i],tint);
        }

        Unit AssistedPartner(Unit actor)
        {
            if(actor.kind==UnitKind.Infected || !actor.active)return null;
            Unit partner=sim.Find(actor.escortId);
            if(partner==null && sim.WingActive && !sim.WingComplete && sim.WingEscortId>=0)
            {
                if(actor.id==sim.WingEscortId)partner=sim.Find(sim.WingResidentId);
                if(actor.id==sim.WingResidentId)partner=sim.Find(sim.WingEscortId);
            }
            if(partner==null && sim.ColumnsActive && !sim.ColumnsComplete)
            {
                for(int c=0;c<sim.ColumnCount && partner==null;c++)
                {
                    if(sim.ColumnFinished(c))continue;
                    int leader=sim.ColumnLeaderId(c);
                    if(leader<0 || (actor.id!=leader && !actor.wounded))continue;
                    float nearest=1.6f*1.6f;
                    for(int n=0;n<sim.ColumnMemberCount(c);n++)
                    {
                        var member=sim.Find(sim.ColumnMemberId(c,n));
                        if(member==null || !member.active || !member.wounded)continue;
                        if(actor==member){partner=sim.Find(leader);break;}
                        if(actor.id!=leader)continue;
                        float d=(actor.pos-member.pos).sqrMagnitude;
                        if(d<nearest){nearest=d;partner=member;}
                    }
                }
            }
            if(partner==null || !partner.active || partner.boarded || (partner.pos-actor.pos).sqrMagnitude>1.6f*1.6f)return null;
            return partner;
        }
    }
}
