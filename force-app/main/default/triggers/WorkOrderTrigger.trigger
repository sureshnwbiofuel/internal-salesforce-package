trigger WorkOrderTrigger on WorkOrder (after update) {

    if(trigger.isAfter && trigger.isUpdate){
        WorkOrderHandlerClass.updateWorkOrder(trigger.new, trigger.oldMap);
    }

}