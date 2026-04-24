public with sharing class OptimoRouteService {

    @AuraEnabled
    public static void syncWorkOrder(Id workOrderId) {
        WorkOrder wo = [
            SELECT Id, WorkOrderNumber
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(
            'callout:OptimoRoute/v1/get_orders?key=f6fcc172cf542552935518b94eaa8923GQtDm0RWMX4&orderNo=' + 
            EncodingUtil.urlEncode(wo.WorkOrderNumber, 'UTF-8')
        );

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('OptimoRoute call failed');
        }

        OptimoResponse response =
            (OptimoResponse) JSON.deserialize(res.getBody(), OptimoResponse.class);

        if (!response.success || response.orders.isEmpty()) {
            throw new AuraHandledException('No order found in OptimoRoute');
        }

        OptimoOrderData data = response.orders[0].data;

        // Map fields
        wo.Duration = data.duration;
        //wo.Priority__c = data.priority;

        update wo;
    }
    
    public class OptimoResponse {
        public Boolean success;
        public List<OptimoOrder> orders;
    }

    public class OptimoOrder {
        public Boolean success;
        public String id;
        public OptimoOrderData data;
    }

    public class OptimoOrderData {
        public String orderNo;
        public String dueDate;
        public Integer duration;
        public String priority;
        public Location location;
    }

    public class Location {
        public String address;
        public Decimal latitude;
        public Decimal longitude;
    }
}