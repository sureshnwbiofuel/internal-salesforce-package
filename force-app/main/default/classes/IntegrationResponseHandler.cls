/**
 * @description This class handles the response logic following a callout to Optimo Route.
 * It processes the HTTP response, parses the JSON results, and updates corresponding 
 * WorkOrder records with their new status and Optimo Order IDs.
 */

 public with sharing class IntegrationResponseHandler {
    
    /**
     * @description Processes the API response and updates WorkOrder statuses.
     * @param res The HttpResponse object received from the Optimo API.
     * @param woIds A set of IDs for the WorkOrders that were included in the request.
     */

    public static void handleOptimoResponse(HttpResponse res, Set<Id> woIds) {
        try{

            // Map to store successful Order Numbers and their returned Optimo IDs
            Map<String,String> mapOfWOandOptimoId = new Map<String,String>();
            
            // Retrieve the WorkOrder records to be updated
            List<WorkOrder> listOfWOs = GetObjectSOQL.getWorkOrderNumbers(woIds); 

            //if response is 200, success is true then update the work order status to Unscheduled and optimo order id else update the work order status to Integration Error
            // 1. Process successful response
            if(res != null && res.getStatusCode() == 200){
                OptimoRouteWrapperResponseClass optimoWrapResponse = (OptimoRouteWrapperResponseClass)JSON.deserialize(res.getBody(),OptimoRouteWrapperResponseClass.class);
                System.debug('Response Body>'+res.getBody());
                if(optimoWrapResponse.success && optimoWrapResponse.orders != null ){
                    for(OptimoRouteWrapperResponseClass.cls_orders order : optimoWrapResponse.orders){
                        if(order.success){
                            mapOfWOandOptimoId.put(order.orderNo,order.id);
                        }
                    }
                }
            }
            // 2. Map statuses based on results
            // Using a single loop to determine the status of EVERY record in the batch.
            // This handles partial success: some may be 'Unscheduled' while others are 'Integration Error'.
            for (WorkOrder wo : listOfWOs) {
                //if (mapOfWOandOptimoId.containsKey(wo.WorkOrderNumber)) { // changed into display
                if (mapOfWOandOptimoId.containsKey(wo.Work_Order_Number_Display__c.substringBetween('>', '</a>'))) {
                    wo.Status = 'Unscheduled';
                    //wo.Optimo_Order_Id__c = mapOfWOandOptimoId.get(wo.WorkOrderNumber); // get with workorder display
                    wo.Optimo_Order_Id__c = mapOfWOandOptimoId.get(wo.Work_Order_Number_Display__c.substringBetween('>', '</a>'));
                } else {
                    // This captures both 400/500 errors AND specific order failures
                    wo.Status = 'Integration Error';
                }
            }    
            
            // STEP 3: Database Update
            if(!listOfWOs.isEmpty()){
                // allOrNone = false allows successful records to save even if others fail DML
                // AccessLevel.USER_MODE ensures Field Level Security (FLS) is respected
                Database.SaveResult[] woList = Database.update(listOfWOs,false,AccessLevel.USER_MODE);
                
                // Log specific DML errors (e.g., validation rule failures)
                for(Database.SaveResult sr : woList){
                    if(!sr.isSuccess()){
                        System.debug(LoggingLevel.ERROR, 'DML Error: ' + sr.getErrors()[0].getMessage());
                    }
                }
            }

        }
        catch(Exception ex){
            // Comprehensive error logging including the stack trace for easier debugging
            System.debug(LoggingLevel.ERROR, 'Exception: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }
}