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
     
/**
 * @description Processes a single QBO API response and updates the corresponding Invoice.
 * @param res The HttpResponse from MuleSoft/QBO.
 * @param invoiceIds The set containing the Invoice ID processed in the callout.
 */
public static void handleQBOResponse(HttpResponse res, Set<Id> invoiceIds) {
    try {
        // 1. Fetch Invoices to be updated
        Map<String, Invoice__c> invoiceMap = new Map<String, Invoice__c>();
        for (Invoice__c inv : [SELECT Id, Name, Invoice_Status__c, QBO_Invoice_ID__c, Ready_for_Integration__c ,
                               Total_Amount__c , Invoice_Creation_Date__c , Due_Date__c, Sales_T__c, Subtotal__c
                               FROM Invoice__c 
                               WHERE Id IN :invoiceIds WITH USER_MODE]) {
            invoiceMap.put(inv.Name, inv);
        }

        if (res != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
            // 2. Deserialize as a single Object instead of a List
            QBO_InvoiceResponseWrapper wrapper = (QBO_InvoiceResponseWrapper)JSON.deserialize(
                res.getBody(), 
                QBO_InvoiceResponseWrapper.class
            );

            if (wrapper != null && wrapper.Invoice != null) {
                QBO_InvoiceResponseWrapper.Invoice qboInv = wrapper.Invoice;
                
                // Use DocNumber (Invoice Name) to find the correct Salesforce record
                if (invoiceMap.containsKey(qboInv.DocNumber)) {
                    Invoice__c sfInv = invoiceMap.get(qboInv.DocNumber);
                    sfInv.Invoice_Status__c = 'Created';
                    sfInv.QBO_Invoice_ID__c = qboInv.Id; // Mapping the QBO internal ID
                    sfInv.Ready_for_Integration__c = false; // Reset gatekeeper to stop re-syncing
                    sfInv.Total_Amount__c  = qboInv.TotalAmt;
                    
                    if (String.isNotBlank(qboInv.DueDate)) {
                        sfInv.Due_Date__c = Date.valueOf(qboInv.DueDate); // Captures "2026-05-06"
                    }
                    
                    if (String.isNotBlank(qboInv.TxnDate)) {
                        // Maps "2026-04-06" to Salesforce Date field
                        sfInv.Invoice_Creation_Date__c = Date.valueOf(qboInv.TxnDate); 
                    }
                    
                    if (qboInv.TxnTaxDetail != null) {
                        sfInv.Sales_T__c = qboInv.TxnTaxDetail.TotalTax;
                    }
                    sfInv.Subtotal__c = sfInv.Total_Amount__c - sfInv.Sales_T__c ;
                }
            }
        } else {
            // 3. Mark all records in this request as error if the callout failed
            for (Invoice__c inv : invoiceMap.values()) {
                inv.Invoice_Status__c = 'Integration Error';
            }
        }

        // 4. Update Database
        if (!invoiceMap.isEmpty()) {
            Database.update(invoiceMap.values(), false, AccessLevel.USER_MODE);
        }
    } catch (Exception ex) {
        System.debug(LoggingLevel.ERROR, 'QBO Response Exception: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
    }
}
}