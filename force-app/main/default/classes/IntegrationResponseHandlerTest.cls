@isTest
private class IntegrationResponseHandlerTest {

    @testSetup
    static void setupData() {
        // 1. Create Account
        Account testAccount = new Account(
            Name = 'Test Optimo Account',
            AccountNumber ='1234',
            Customer_ID__c = '124',
            ShippingStreet = '123 Test St',
            ShippingCity = 'Test City',
            ShippingState = 'CA',
            ShippingPostalCode = '90000',
            ShippingCountry = 'USA'
            
            // Add other mandatory fields here if your org requires them
        );
        insert testAccount;
        
        // 2. Create Services_Needed__c (Custom Object)
        // Note: We are populating fields referenced in the query to ensure data integrity
        Services_Needed__c testService = new Services_Needed__c(
            Account__c = testAccount.Id,
            Order_Type__c = 'T',
            Duration_In_Mins__c = 60,
            Rate__c = 100.00
            // Add other mandatory fields here
        );
        insert testService;

        // Create WorkOrders
        List<WorkOrder> wos = new List<WorkOrder>();
        wos.add(new WorkOrder(Status = 'New', AccountId = testAccount.Id,Services_Needed__c = testService.Id));
        wos.add(new WorkOrder( Status = 'New', AccountId = testAccount.Id,Services_Needed__c = testService.Id));
        insert wos;
    }

    /**
     * @description Tests the happy path where the API returns success for all orders.
     */
    @isTest
    static void testHandleOptimoResponse_FullSuccess() {
        // 1. Fetch created WOs to get their auto-generated WorkOrderNumbers
        List<WorkOrder> wos = [SELECT Id, WorkOrderNumber,Work_Order_Number_Display__c FROM WorkOrder ORDER BY Subject];
        Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();
        
        String woNum1 = wos[0].Work_Order_Number_Display__c.substringBetween('>', '</a>'); // WO Failure (alphabetical)
        String woNum2 = wos[1].Work_Order_Number_Display__c.substringBetween('>', '</a>'); // WO Success

        // 2. Construct valid JSON Response matching the Wrapper structure
        String jsonBody = '{' +
            '"success": true,' +
            '"orders": [' +
                '{"orderNo": "' + woNum1 + '", "id": "OPT-001", "success": true},' +
                '{"orderNo": "' + woNum2 + '", "id": "OPT-002", "success": true}' +
            ']' +
        '}';

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(jsonBody);

        // 3. Execute Method
        Test.startTest();
        IntegrationResponseHandler.handleOptimoResponse(res, woIds);
        Test.stopTest();

        // 4. Assert Results
        List<WorkOrder> updatedWOs = [SELECT Id, Status, Optimo_Order_Id__c FROM WorkOrder WHERE Id IN :woIds];
        
        for (WorkOrder wo : updatedWOs) {
            System.assertEquals('Unscheduled', wo.Status, 'Status should be updated to Unscheduled on success');
            System.assert(wo.Optimo_Order_Id__c != null, 'Optimo ID should be populated');
        }
    }

    /**
     * @description Tests a partial success scenario: One success, one failure/missing in response.
     */
    @isTest
    static void testHandleOptimoResponse_PartialSuccess() {
        List<WorkOrder> wos = [SELECT Id, WorkOrderNumber,Work_Order_Number_Display__c FROM WorkOrder ORDER BY Subject]; // WO Failure, WO Success
        Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();
        
        String failureWONum = wos[0].Work_Order_Number_Display__c.substringBetween('>', '</a>');
        String successWONum = wos[1].Work_Order_Number_Display__c.substringBetween('>', '</a>');

        // JSON: Success WO is true, Failure WO is explicitly false
        String jsonBody = '{' +
            '"success": true,' +
            '"orders": [' +
                '{"orderNo": "' + successWONum + '", "id": "OPT-999", "success": true},' +
                '{"orderNo": "' + failureWONum + '", "id": null, "success": false}' +
            ']' +
        '}';

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(jsonBody);

        Test.startTest();
        IntegrationResponseHandler.handleOptimoResponse(res, woIds);
        Test.stopTest();

        // Assertions
        WorkOrder successWO = [SELECT Status, Optimo_Order_Id__c FROM WorkOrder WHERE Id = :wos[1].Id];
        WorkOrder failedWO = [SELECT Status, Optimo_Order_Id__c FROM WorkOrder WHERE Id = :wos[0].Id];

        System.assertEquals('Unscheduled', successWO.Status, 'Successful order should be Unscheduled');
        System.assertEquals('OPT-999', successWO.Optimo_Order_Id__c, 'Successful order should have ID');
        
        System.assertEquals('Integration Error', failedWO.Status, 'Failed order in JSON should be Integration Error');
        System.assertEquals(null, failedWO.Optimo_Order_Id__c, 'Failed order should not have Optimo ID');
    }

    /**
     * @description Tests the scenario where the API returns a 400/500 error.
     */
    @isTest
    static void testHandleOptimoResponse_ApiError() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder];
        Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();

        HttpResponse res = new HttpResponse();
        res.setStatusCode(500);
        res.setBody('{"error": "Internal Server Error"}');

        Test.startTest();
        IntegrationResponseHandler.handleOptimoResponse(res, woIds);
        Test.stopTest();

        List<WorkOrder> updatedWOs = [SELECT Status FROM WorkOrder];
        for (WorkOrder wo : updatedWOs) {
            System.assertEquals('Integration Error', wo.Status, 'All records should be Integration Error on API failure');
        }
    }

    /**
     * @description Tests how the code handles malformed JSON (Exception handling check).
     */
    @isTest
    static void testHandleOptimoResponse_MalformedJson() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder];
        Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{ "success": true, "orders": [ BROKEN JSON... '); // Invalid JSON

        Test.startTest();
        // This should be caught by the try/catch block and not crash the test
        IntegrationResponseHandler.handleOptimoResponse(res, woIds);
        Test.stopTest();

        // Since the JSON failed to parse, the code inside the 'if(200)' block fails or creates empty map.
        // The loop 'for (WorkOrder wo : listOfWOs)' will run, see map is empty, and set all to Integration Error.
        // Or, if the exception happens before the loop, records might remain 'New'. 
        // Based on your code, the Exception block is at the top level, so NO updates occur if JSON fails immediately.
        
        List<WorkOrder> updatedWOs = [SELECT Status FROM WorkOrder];
        for (WorkOrder wo : updatedWOs) {
            // Because the exception is caught and the DML is inside the try block (after parsing),
            // the DML will never run. Status should remain 'New'.
            System.assertEquals('New', wo.Status, 'Status should remain unchanged if JSON parsing throws exception');
        }
    }
}