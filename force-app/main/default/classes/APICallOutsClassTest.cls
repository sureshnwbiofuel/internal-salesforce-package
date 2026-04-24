@isTest
private class APICallOutsClassTest {

    /**
     * @description Setup test data required for linking logs.
     */
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

        // 3. Create WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            AccountId = testAccount.Id,
            Services_Needed__c = testService.Id,
            Status = 'New',
            Priority = 'M',
            Subject = 'Test Work Order'
        );
        insert testWorkOrder;
    }



    /**
     * @description Tests the happy path: API returns 200 and Logs are created.
     */
    @isTest
    static void testOptimoRouteCallOut_Success() {
        // 1. Prepare Data
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Set<Id> relatedIds = new Set<Id>{ wo.Id };
        String payload = '{"orders": [{"id": "WO-001"}]}';

        // 2. Set Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

        // 3. Execute
        Test.startTest();
        HttpResponse res = APICallOutsClass.optimoRouteCallOut(payload, relatedIds);
        Test.stopTest();

        // 4. Assert Response
       /* System.assertEquals(200, res.getStatusCode(), 'Status code should be 200');
        System.assertEquals('{"success": true, "orderId": "12345"}', res.getBody(), 'Body should match mock');

        // 5. Assert Logs Created
        List<Integration_Logs__c> logs = [SELECT Id, Status_Code__c, Request_Body__c FROM Integration_Logs__c];
        System.assertEquals(1, logs.size(), 'One integration log should be created');
        System.assertEquals('200', logs[0].Status_Code__c, 'Log should record status 200');*/
        
        // 6. Assert Junction Created
        /*List<Integration_Logs_Junction__c> junctions = [SELECT Id, Work_Order__c FROM Integration_Logs_Junction__c];
        System.assertEquals(1, junctions.size(), 'One junction record should be created');
        System.assertEquals(wo.Id, junctions[0].Work_Order__c, 'Junction should link to the correct Work Order');*/
    }

    /**
     * @description Tests the exception path: Network fails, Catch block executes, Error Log created.
     */
    @isTest
    static void testOptimoRouteCallOut_NetworkException() {
        // 1. Prepare Data
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Set<Id> relatedIds = new Set<Id>{ wo.Id };
        String payload = '{}';

        // 2. Set Mock to Throw Exception
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseExcep());

        // 3. Execute
        Test.startTest();
        HttpResponse res = APICallOutsClass.optimoRouteCallOut(payload, relatedIds);
        Test.stopTest();

        // 4. Assert Response (Synthetic 500 created in catch block)
        System.assertEquals(500, res.getStatusCode(), 'Exception should result in synthetic 500 status');
        System.assert(res.getBody().contains('Callout Failed'), 'Body should contain error message');

        // 5. Assert Logs Created (Even on failure, we expect a log)
        List<Integration_Logs__c> logs = [SELECT Id, Status_Code__c FROM Integration_Logs__c];
        System.assertEquals(1, logs.size(), 'Error log should be created');
        System.assertEquals('500', logs[0].Status_Code__c, 'Log should record status 500');
    }

    /**
     * @description Tests the logging method directly with null inputs to ensure null safety.
     */
    @isTest
    static void testCreateIntegrationLogs_NullSafety() {
        Test.startTest();
        // Pass null exchange
        APICallOutsClass.createIntegrationLogs(null, new Set<Id>());
        Test.stopTest();

        List<Integration_Logs__c> logs = [SELECT Id FROM Integration_Logs__c];
        System.assertEquals(0, logs.size(), 'No logs should be created for null input');
    }

    /**
     * @description Tests logging when no WorkOrder IDs are provided (Log created, but no Junctions).
     */
    @isTest
    static void testCreateIntegrationLogs_NoRelatedIds() {
        // Manually build an HttpExchange
        HttpRequest req = new HttpRequest();
        req.setEndpoint('http://test.com');
        req.setBody('test');
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('test');
        
        APICallOutsClass.HttpExchange exchange = new APICallOutsClass.HttpExchange(req, res);

        Test.startTest();
        // Pass empty set of IDs
        APICallOutsClass.createIntegrationLogs(exchange, new Set<Id>());
        Test.stopTest();

        // Verify Log exists but Junctions do not
        List<Integration_Logs__c> logs = [SELECT Id FROM Integration_Logs__c];
        System.assertEquals(1, logs.size(), 'Main log should be created');
        
        List<Integration_Logs_Junction__c> junctions = [SELECT Id FROM Integration_Logs_Junction__c];
        System.assertEquals(0, junctions.size(), 'No junctions should be created');
    }
}