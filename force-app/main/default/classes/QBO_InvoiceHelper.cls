/**
 * @description Refactored Helper to match the specific QBO_InvoiceRequestWrapper structure.
 */
public with sharing class QBO_InvoiceHelper {

    public static void processInvoices(List<Invoice__c> scope, List<Id> workOrderIds) {
        Set<Id> invoiceIds = new Set<Id>();
        for(Invoice__c inv : scope) { invoiceIds.add(inv.Id); }

        // 1. Fetch data using the Selector
        List<WorkOrder> allWorkOrders;

    	// Check if workOrderIds is provided
        if (workOrderIds != null && !workOrderIds.isEmpty()) {
            allWorkOrders = QBO_Selector.getWorkOrdersById(workOrderIds);
        } else {
            allWorkOrders = QBO_Selector.getWorkOrdersForInvoices(invoiceIds);
        }
        
        Set<String> terms = new Set<String>();
        Set<String> classes = new Set<String>();
        Set<String> items = new Set<String>();

        // 2. Group Work Orders by Invoice ID
        Map<Id, List<WorkOrder>> invoiceToWOMap = new Map<Id, List<WorkOrder>>();
        for(WorkOrder wo : allWorkOrders) {
            if(wo.Account.Payment_Term__c != null) terms.add(wo.Account.Payment_Term__c);
            if(wo.Connected_Fixture__c != null) classes.add(wo.Connected_Fixture__c);
            // Collect Record Type Names for Item matching
            if(wo.Services_Needed__r.RecordType.Name != null || wo.Rate__c != null ||  wo.Volume__c != null){
                items.add(wo.Services_Needed__r.RecordType.Name+'_'+wo.Volume__c+'_'+wo.Rate__c);
            } 
            
            if(!invoiceToWOMap.containsKey(wo.Invoice__c)) {
                invoiceToWOMap.put(wo.Invoice__c, new List<WorkOrder>());
            }
            invoiceToWOMap.get(wo.Invoice__c).add(wo);
        }
        
        Map<String, String> intMap = QBO_Selector.getIntegrationMappings(terms,classes,items);

        // 3. Build and Send Payloads
        //List<QBO_InvoiceRequestWrapper> listQBOInvoiceRequest = new List<QBO_InvoiceRequestWrapper>(); Payload Request Bulkification
        for(Invoice__c inv : scope) {
            if(invoiceToWOMap.containsKey(inv.Id)) {
                QBO_InvoiceRequestWrapper request = buildPayload(inv, invoiceToWOMap.get(inv.Id),intMap);
                //listQBOInvoiceRequest.add(request); // Payload Request Bulkification
                executeCallout(inv.Id, JSON.serialize(request.inPayload));
            }
        }
        
    }

    private static QBO_InvoiceRequestWrapper buildPayload(Invoice__c inv, List<WorkOrder> workOrders, Map<String, String> intMap) {
        
        WorkOrder firstWO = workOrders[0];
        
        QBO_InvoiceRequestWrapper root = new QBO_InvoiceRequestWrapper();
        root.inPayload = new QBO_InvoiceRequestWrapper.InPayload();
        
        // Header Mapping
        root.inPayload.DocNumber = inv.Name; // Using Invoice Name as DocNumber
                
        root.inPayload.CustomerRef = new QBO_InvoiceRequestWrapper.CustomerRef();
        root.inPayload.CustomerRef.value = firstWO.Account.Customer_ID__c;
        root.inPayload.CustomerRef.name = firstWO.Account.Name;
        
        root.inPayload.EmailStatus = 'NeedToSend';
        
        root.inPayload.BillEmail = new QBO_InvoiceRequestWrapper.BillEmail();
        root.inPayload.BillEmail.Address = firstWO.Account.Billing_Email__c;

        root.inPayload.SalesTermRef = new QBO_InvoiceRequestWrapper.SalesTermRef();
        root.inPayload.SalesTermRef.value = intMap.get(firstWO.Account.Payment_Term__c);
        root.inPayload.SalesTermRef.name = firstWO.Account.Payment_Term__c;

        // Line Item Mapping
        root.inPayload.Line = new List<QBO_InvoiceRequestWrapper.Line>();
        Integer lineCounter = 1;

        for(WorkOrder wo : workOrders) {
            
            Decimal calculatedQty = 0;
            String rtName = wo.Services_Needed__r.RecordType.Name;
            Decimal duration = wo.Service_Duration_In_Mins__c;
            
            // Note: We use the exact key format you built in the Selector
            String itemKey = rtName + '_' + wo.Volume__c + '_' + wo.Rate__c;
            String itemData = intMap.get(itemKey);
        
            if(rtName == 'Drain Cleaning' && duration != null) {
                calculatedQty = (duration / 60.0).setScale(2); // Logic: 60 = 1.0, 75 = 1.25, 90 = 1.5
            } else {
                calculatedQty = 1.0; // Default quantity for other record types (e.g., Grease Trap might be 1 per job)
            }
            
            QBO_InvoiceRequestWrapper.Line line = new QBO_InvoiceRequestWrapper.Line();
            line.LineNum = lineCounter++;
            line.Description = wo.Volume__c != null ? string.valueOf(wo.Volume__c) : null;
            line.Amount  = wo.Rate__c != null ? (wo.Rate__c * calculatedQty).setScale(2)  : null; 
            line.DetailType = 'SalesItemLineDetail';
            
            line.SalesItemLineDetail = new QBO_InvoiceRequestWrapper.SalesItemLineDetail();
            line.SalesItemLineDetail.ServiceDate = wo.Order_Date__c != null ? string.valueOf(wo.Order_Date__c) : null;
            
            // Map Item and Class Refs
            line.SalesItemLineDetail.ItemRef = new QBO_InvoiceRequestWrapper.ItemRef();
            line.SalesItemLineDetail.ItemRef.value = itemData.split('_')[1]; //ID
            line.SalesItemLineDetail.ItemRef.name = itemData.split('_')[0]; //Full_Name__c
            
            line.SalesItemLineDetail.ClassRef = new QBO_InvoiceRequestWrapper.ClassRef();
            line.SalesItemLineDetail.ClassRef.value = intMap.get(wo.Connected_Fixture__c); // Note: Ensure this is the ID value
            line.SalesItemLineDetail.ClassRef.name = wo.Connected_Fixture__c; 
            
            // Check for Washington state (handling both abbreviation and full name)
            String shipState = wo.Account.ShippingState;
            if (String.isNotBlank(shipState) && (shipState.equalsIgnoreCase('WA') || shipState.equalsIgnoreCase('Washington'))) {
                line.SalesItemLineDetail.TaxCodeRef = new QBO_InvoiceRequestWrapper.TaxCodeRef();
                line.SalesItemLineDetail.TaxCodeRef.value = 'TAX'; // Constant for QBO
            } else {
                line.SalesItemLineDetail.TaxCodeRef = null;
            }
            
            line.SalesItemLineDetail.UnitPrice = wo.Rate__c != null ? wo.Rate__c : null;
			line.SalesItemLineDetail.Qty = calculatedQty;
            
            root.inPayload.Line.add(line);
        }

        return root;
    }

    private static void executeCallout(Id invId, String body) {
        System.debug('Final QBO Payload: ' + body);
       /* Integration_Logs__c intg = [Select Id,Request_Body__c FROM Integration_Logs__c where Id = 'a07WI0000Nn0UPcYQM'] ;
        intg.Request_Body__c = body;
        update intg;*/
        Set<Id> invoiceIds = new Set<Id>();
        invoiceIds.add(invId);
        HttpResponse res = APICallOutsClass.qboCallOut(body, invoiceIds);
        // 5. Delegate Response Handling
        if (res != null) {
            IntegrationResponseHandler.handleQBOResponse(res, invoiceIds);
        } 
    }
}