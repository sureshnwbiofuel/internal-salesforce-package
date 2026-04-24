public with sharing class OptimoRouteBulkService {

    @InvocableMethod(label='Sync Work Orders from OptimoRoute')
    public static void syncOrders(List<List<String>> itemsList) {

        List<String> recordIds = itemsList[0];
        
        if(recordIds == null || recordIds.isEmpty()) return;
        
        List<Id> workOrderIds = new List<Id>();
        for (String rid : recordIds) {
            workOrderIds.add((Id) rid);
        }
        List<WorkOrder> workOrders = [
            SELECT Id, WorkOrderNumber
            FROM WorkOrder
            WHERE Id IN :workOrderIds
        ];

        List<WorkOrder> updates = new List<WorkOrder>();

        for (WorkOrder wo : workOrders) {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(
                'callout:OptimoRoute/v1/get_orders?orderNo=' +
                EncodingUtil.urlEncode(wo.WorkOrderNumber, 'UTF-8')
            );

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) continue;

            OptimoResponse response =
                (OptimoResponse) JSON.deserialize(res.getBody(), OptimoResponse.class);

            if (!response.success || response.orders.isEmpty()) continue;

            OptimoOrderData data = response.orders[0].data;

            wo.Duration = data.duration;
            //wo.Priority__c = data.priority;

            updates.add(wo);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
    public class OptimoResponse {
        public Boolean success;
        public List<OptimoOrder> orders;
    }
    
    public class OptimoOrder {
        public Boolean success;
        public OptimoOrderData data;
    }
    
    public class OptimoOrderData {
        public String orderNo;
        public String dueDate;
        public Integer duration;
        public String priority;
    }
    public class WorkOrderRequest {
        @InvocableVariable(required=true)
        public String recordId;
    }
}