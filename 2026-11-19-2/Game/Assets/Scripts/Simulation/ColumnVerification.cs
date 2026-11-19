#if UNITY_EDITOR
using System;
using System.Text;
using UnityEngine;
namespace Evac
{
    public partial class GameSim
    {
        internal void ManualColumnTrip(int c,int route)
        {
            var u=Controlled;
            for(int i=0;i<3000 && !ColumnFinished(c) && Result==SimResult.Active;i++){
                if(ColumnHeld(c) && CanCommandColumn(c,route,u.squad))CommandColumn(c,route,u.squad);
                Vector3 goal=ColumnHeld(c)?ColumnPosition(c):ColumnDestination(c);
                // Keep the tail within speaking distance, especially while turning around obstructions.
                if(!ColumnHeld(c)){
                    float far=0;Vector3 tail=u.pos;
                    for(int j=0;j<ColumnMemberCount(c);j++){var rider=Find(ColumnMemberId(c,j));if(!rider.active)continue;float d=FlatSq(rider.pos,u.pos);if(d>far){far=d;tail=rider.pos;}}
                    if(far>28)goal=tail;
                }
                var delta=RouteWaypoint(u.pos,goal)-u.pos;
                Move(Vector3.ClampMagnitude(delta/.53f,1),Mathf.Atan2(delta.x,delta.z)*Mathf.Rad2Deg,.1f);
                Tick(.1f);
            }
            Verify(ColumnFinished(c),"Manual column "+c+" "+ColumnStatus(c)+" "+u.pos+" "+ColumnPosition(c)+" "+ColumnDestination(c)+" "+Result);
        }

        void VerifyColumnContactBarrier(Unit worker,Unit patient)
        {
            var start=worker.pos;var prior=patient.pos;
            // The middle room's closed gate separates two nearby walkable points.
            var gate=new Vector3(-3.5f,0,120);
            worker.pos=Ground(gate-Vector3.right*1.2f);patient.pos=Ground(gate+Vector3.right*1.2f);
            float distance=Vector3.Distance(worker.pos,patient.pos);
            Verify(distance<3.5f && !CanCommandColumn(1,7,worker.squad) && !CanCommandColumn(1,6,worker.squad),
                "Nearby closed room door blocks medical and stretcher transfer");
            worker.pos=Ground(new Vector3(0,0,90));patient.pos=Ground(worker.pos+Vector3.forward*distance);
            Verify(CanCommandColumn(1,7,worker.squad) && CanCommandColumn(1,6,worker.squad),"Same range with visible contact permits first aid and pickup");
            var panel=ColumnControlPoint(1);
            worker.pos=Ground(panel+Vector3.left*2.5f);Verify(!CanCommandColumn(1,4,worker.squad),"Solid control cabinet blocks the rear approach");
            worker.pos=Ground(panel+Vector3.right*2.5f);Verify(CanCommandColumn(1,4,worker.squad),"Reachable front of control cabinet");
            worker.pos=start;patient.pos=prior;
        }
        void VerifyRemoteColumnAccess()
        {
            StartMission(5,Difficulty.Story);Chapter.phase=2;Tick(.1f);
            var holder=soldiers[0];var alternate=soldiers[3];var patient=Find(ColumnMemberId(1,1));
            var gate=new Vector3(-3.5f,0,120);
            patient.pos=Ground(gate+Vector3.right*1.1f);
            holder.pos=patient.pos+Vector3.forward*.4f;
            alternate.pos=Ground(gate-Vector3.right*1.1f);
            Verify(Possess(holder.id) && CommandColumn(1,7,0),"Holder picks up on clear side");
            Release();
            Verify(CommandColumn(1,7,1) && Line(1).pickup==alternate.id,"Send actual replacement on far side");
            Tick(.08f);
            Verify(ColumnCarrierId(1)==holder.id && Line(1).pickup==alternate.id,"Nearby relief cannot transfer through closed door");
            Verify(Possess(holder.id) && CommandColumn(1,7,0) && ColumnCarrierId(1)<0 && Line(1).pickup==alternate.id && Notice.Contains("交代"),
                "Holder can set down before relief arrives; the existing assignment stays visible");
            Release();
            for(int i=0;i<1600 && ColumnCarrierId(1)!=alternate.id;i++)Tick(.1f);
            Verify(ColumnCarrierId(1)==alternate.id && geometry.LineClear(alternate.pos+Vector3.up,patient.pos+Vector3.up),"Relief actually walked around the closed door to receive patient");
            Verify(Possess(alternate.id) && CommandColumn(1,7,1),"Relief sets down before medical test");
            Release();
            patient.pos=Ground(gate+Vector3.right*1.1f);holder.pos=Ground(gate-Vector3.right*1.1f);
            int kits=MedicalSupplies;
            Verify(CommandColumn(1,6,0),"Send doctor on far side");
            Tick(.08f);
            Verify(MedicalSupplies==kits && patient.wounded,"Closed door prevents remote medical use");
            for(int i=0;i<1600 && patient.wounded;i++)Tick(.1f);
            Verify(!patient.wounded && MedicalSupplies==kits-1,"After actual detour one kit treats patient");
            var operatorUnit=soldiers[6];var panel=ColumnControlPoint(1);
            operatorUnit.pos=Ground(panel+Vector3.left*2.35f);
            Verify(CommandColumn(1,4,2),"Send engineer from cabinet rear");
            Tick(.08f);
            Verify(!ColumnControlOpen(1) && Line(1).operatorId==operatorUnit.id,"Cannot operate through back of cabinet");
            for(int i=0;i<500 && !ColumnControlOpen(1);i++)Tick(.1f);
            Verify(ColumnControlOpen(1),"Operator walked around cabinet and opened service door");
        }

        internal void VerifyColumns(StringBuilder report)
        {
            VerifyRemoteColumnAccess();
            StartMission(0,Difficulty.Story);Chapter.phase=2;Tick(.1f);
            Verify(ColumnCount==1 && ColumnMemberCount(0)==2 && !ColumnsComplete,"Market roster");
            var pawn=soldiers[0];Verify(Possess(pawn.id),"Possess market guide");
            Verify(!CanCommandColumn(0,0,0),"Cannot call from another street in FPS");
            ManualColumnTrip(0,1);
            Verify(Line(0).arrived==2 && ColumnMemberOutcome(0,0)==1,"Two actual market residents handed off");
            report.AppendLine("Market FPS lead "+Elapsed.ToString("0.0")+"s; both residents physically reached the bus.");

            StartMission(5,Difficulty.Story);Chapter.phase=2;Tick(.1f);
            Verify(ColumnCount==2 && ColumnMemberCount(1)==4,"Two station columns");
            Verify(CommandColumn(0,0,0) && CommandColumn(1,1,1) && CommandColumn(1,4,2),"Split guides and station operator");
            for(int i=0;i<2200 && (Line(0).leg==0 || Line(1).leg==0) && Result==SimResult.Active;i++)Tick(.1f);
            Verify(Line(0).leg==1 && Line(1).leg==1 && Line(1).open,"Two physical groups held in different refuges "+ColumnStatus(0)+" "+ColumnStatus(1)+" "+Result);
            Verify(!CanCommandColumn(1,5,1) && Save() && Load(),"Cannot abandon both groups; checkpoint state valid");
            var position=ColumnPosition(1);
            Verify(CommandColumn(0,0,0) && SetPower(PowerCircuit.Lift,false),"Close lift while north group is waiting");
            for(int i=0;i<20;i++)Tick(.1f);
            Verify(!ColumnPassable(0) && FlatSq(position,ColumnPosition(1))<.01f,"Lift legitimately blocked; south column remains sheltered");
            Verify(CommandColumn(0,1,0),"Change north group onto opened service passage");
            for(int i=0;i<2500 && !ColumnFinished(0) && Result==SimResult.Active;i++)Tick(.1f);
            Verify(ColumnFinished(0) && Line(0).arrived>0 && CommandColumn(1,5,1),"Physically delivered first group before partial departure "+ColumnStatus(0)+" "+Result);
            Verify(Line(1).sheltered==4 && ColumnMemberOutcome(1,0)==2 && ColumnsComplete && Save() && Load() && ColumnsComplete,"Partial departure preserved");
            RecordColumns(5);
            Verify(CampaignColumnSheltered(5)==4 && CampaignColumnRescued(5)==Line(0).arrived,"Partial archive correct");
            report.AppendLine("Flood split/hold, two refuges, power loss, physical bypass and partial handoff "+Elapsed.ToString("0.0")+"s.");

            StartMission(5,Difficulty.Story);Chapter.phase=2;Tick(.1f);
            var medic=soldiers[0];var porter=soldiers[1];var sick=Find(ColumnMemberId(1,1));
            // Starting beside the patients isolates the field handover. Movement below uses real input.
            medic.pos=Ground(sick.pos+Vector3.back);porter.pos=Ground(sick.pos+Vector3.right);
            Verify(Possess(medic.id),"Enter physical rescue test");
            VerifyColumnContactBarrier(medic,sick);
            Brain(medic).cargo=true;Verify(!CanCommandColumn(1,7,medic.squad),"Occupied cargo hands cannot take stretcher");Brain(medic).cargo=false;
            Brain(medic).escort=soldiers[2].id;Verify(!CanCommandColumn(1,7,medic.squad),"Ordinary escort cannot take stretcher");Brain(medic).escort=-1;
            Verify(Possess(medic.id) && CommandColumn(1,7,medic.squad) && ColumnCarrierId(1)==medic.id && Notice.Contains("引き継いだ"),"Local stretcher pickup with completed action notice");
            var oldWorker=medic.pos;var oldPatient=sick.pos;
            medic.pos=Ground(new Vector3(-4.7f,0,120));sick.pos=Ground(new Vector3(-2.3f,0,120));
            Verify(CommandColumn(1,7,medic.squad) && ColumnCarrierId(1)<0 && Notice.Contains("下ろした"),"Holder can release even at an obstructed doorway");
            medic.pos=oldWorker;sick.pos=oldPatient;Verify(CommandColumn(1,7,medic.squad),"Pick up at the original clear side");
            for(int i=0;i<20;i++){Move(Vector3.zero,0,.1f);Tick(.1f);}
            var front=sick.pos-medic.pos;
            Verify(Vector3.Dot(front,Vector3.forward)>1 && front.magnitude<1.6f && !Shoot(Vector3.forward) && !Dodge(Vector3.right),"Actual front-facing stretcher and occupied hands");
            Verify(Save() && Load() && ColumnCarrierId(1)==medic.id && ColumnCarriedId(1)==sick.id,"Stretcher passenger is durable");
            medic=Find(medic.id);porter=Find(porter.id);sick=Find(sick.id);
            Verify(Possess(porter.id),"Transfer view to replacement");
            for(int i=0;i<300 && !CanCommandColumn(1,7,porter.squad);i++){
                var dir=RouteWaypoint(porter.pos,sick.pos)-porter.pos;Move(Vector3.ClampMagnitude(dir/.53f,1),0,.1f);Tick(.1f);
            }
            Verify(CommandColumn(1,7,porter.squad) && ColumnCarrierId(1)==porter.id,"Local handover between two soldiers");
            Verify(CommandColumn(1,7,porter.squad) && ColumnCarrierId(1)<0 && Notice.Contains("下ろした"),"Local set-down keeps actual patient with completed action notice");
            int stock=MedicalSupplies;
            Verify(CommandColumn(1,6,porter.squad) && MedicalSupplies==stock-1 && !sick.wounded,"Durable physical treatment costs a kit");
            Release();
            Verify(CommandColumn(0,4,0),"Dispatch public-address operator");
            for(int i=0;i<1800 && !ColumnControlOpen(0);i++)Tick(.1f);
            Verify(ColumnControlOpen(0) && CommandColumn(0,0,0) && ColumnLeaderId(0)==-1,"Speaker releases field escort");
            report.AppendLine("Physical front wheels, hands, shared patient ID across transfer and save, actual medical resource, PA releases guide.");
            StartMission(5,Difficulty.Story);Chapter.phase=2;Tick(.1f);
            Order(0,SquadOrder.Guard,Route.exit);
            Verify(CommandColumn(1,1,1) && CommandColumn(1,4,2),"Select dry passage and open fire door");
            for(int i=0;i<1800 && (Line(1).leg<1 || !Line(1).open);i++)Tick(.1f);
            Verify(Line(1).leg==1 && Line(1).open && CommandColumn(1,1,1),"Proceed to service stairs");
            for(int i=0;i<900 && Find(ColumnMemberId(1,1)).pos.z>56;i++)Tick(.1f);
            var waiting=Find(ColumnMemberId(1,1));
            Verify(waiting.active && waiting.wounded && !Brain(waiting).columnStairs,"Severe unassisted patient cannot cross stairs");
            Verify(CommandColumn(1,7,2),"Send physical bearer to stairs");
            for(int i=0;i<2500 && !ColumnFinished(1) && Result==SimResult.Active;i++)Tick(.1f);
            Verify(Line(1).arrived==4 && ColumnMemberOutcome(1,1)==1,"Full dry stair rescue "+Result+" time "+Elapsed+" vehicle "+VehicleHealth+" leader "+ColumnLeaderId(1)+" carrier "+ColumnCarrierId(1)+" per "+string.Join(",",Array.ConvertAll(Line(1).people, id=>Find(id).pos.ToString()+"/"+Brain(Find(id)).columnStairs))+" "+ColumnStatus(1)+" guide "+Find(ColumnLeaderId(1))?.pos+" chair "+waiting.pos+" group "+ColumnPosition(1)+" leg "+Line(1).leg+" goal "+ColumnDestination(1));
            report.AppendLine("Dry route: severe patient stopped at the stair, bearer picked up the loaded stretcher, all four arrived. "+Elapsed.ToString("0.0")+"s.");
            StartMission(5,Difficulty.Story);Chapter.phase=2;Tick(.1f);
            Order(1,SquadOrder.Guide,ActiveAssembly);Order(2,SquadOrder.Guard,Route.exit);
            Verify(Possess(soldiers[0].id),"One FPS field guide at rail entrance");
            ManualColumnTrip(0,0);ManualColumnTrip(1,0);
            Verify(ColumnsComplete && Line(0).arrived+Line(1).arrived==8,"One FPS soldier sequentially guided both groups on powered route");
            report.AppendLine("Full station FPS: one operator led both entire columns, "+Elapsed.ToString("0.0")+"s, lift seats shared with street.");
            StartOperation(5,Difficulty.Story,false,true,false);Chapter.phase=2;Tick(.1f);
            Verify(Save() && Load() && !ColumnsActive && ColumnCount==0,"0.3 state exempt");
        }
    }
}
#endif
