public with sharing class WorkOrderHandlerClass {
    
    public static void updateWorkOrder(List<WorkOrder> newWorkOrderList,Map<Id,WorkOrder> oldWorkOrderMap) {
        
        set<Id> setOfReadyWOrkOrderIds = new Set<Id>();
        set<Id> setOfServiceNeededIds = new Set<Id>();

        //Check for WO status is updated to Ready and capture WO Ids and Account/ServiceNeeded Ids
        for(WorkOrder wo : newWorkOrderList){
            if(wo.status == 'Ready' && wo.status != oldWorkOrderMap.get(wo.Id).status){
                setOfReadyWOrkOrderIds.add(wo.Id);
                setOfServiceNeededIds.add(wo.Services_Needed__c);
            }
        }

        //Pass the Ids WorkOrderHelperClass 
        if(!setOfReadyWOrkOrderIds.isEmpty()){
            WorkOrderHelperClass.createUpdateWOToOptimo(setOfReadyWOrkOrderIds,setOfServiceNeededIds);
        }
    }
}