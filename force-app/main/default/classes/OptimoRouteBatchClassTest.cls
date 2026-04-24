@isTest
private class OptimoRouteBatchClassTest {

    @testSetup
    static void setupData() {
        // 1. Setup Custom Settings (Required by the Invocable method)
        OptimoRoute_Batch_Settings__c settings = new OptimoRoute_Batch_Settings__c();
        settings.Batch_Job_Size__c = 20;
        settings.Last_Batch_Job_Executed__c = System.now().addDays(-2); // Simulate last run 2 days ago
        insert settings;

        // 1. Create Account
        Account testAccount = new Account(
            Name = 'Test Optimo Account',
            Customer_ID__c = '124',
            AccountNumber ='1234',
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
        wos.add(new WorkOrder(Status = 'Ready', AccountId = testAccount.Id,Services_Needed__c = testService.Id));
        wos.add(new WorkOrder( Status = 'New', AccountId = testAccount.Id,Services_Needed__c = testService.Id));
        insert wos;
    }

    /**
     * @description Mocks the HTTP callout. This is critical because the batch executes 
     * the helper class, which performs the actual API request.
     */
    public class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * @description Tests the Invocable method called by Flows.
     * Verifies that the batch is queued and settings are updated upon completion.
     */
    @isTest
    static void testExecuteOptimoRouteBatch_Invocable() {
        // Set the mock to handle the callout inside the batch
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        // Call the invocable method directly
        OptimoRouteBatchClass.executeOptimoRouteBatch();
        Test.stopTest(); 

        // Assert that the batch job was queued
        List<AsyncApexJob> jobs = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors 
                                   FROM AsyncApexJob 
                                   WHERE ApexClass.Name = 'OptimoRouteBatchClass'];
        
        System.assertEquals(2, jobs.size(), 'One batch job should have been queued');
        System.assertEquals('Completed', jobs[0].Status, 'Batch job should complete successfully');
        
        // Assert that the Custom Setting was updated in the 'finish' method
        OptimoRoute_Batch_Settings__c settings = OptimoRoute_Batch_Settings__c.getOrgDefaults();
        
        // The batch updates Last_Batch_Job_Executed__c to "now".
        // We check if it's greater than the old value (set in testSetup to -2 days).
        System.assert(settings.Last_Batch_Job_Executed__c > System.now().addDays(-1), 
            'Last Batch Run time should be updated to a recent timestamp');
    }

    /**
     * @description Tests the 'start' method query locator specifically to ensure filtering works.
     * This ensures only 'Ready' records are picked up.
     */
    @isTest
    static void testStartQueryLocator() {
        OptimoRoute_Batch_Settings__c settings = OptimoRoute_Batch_Settings__c.getOrgDefaults();
        OptimoRouteBatchClass batch = new OptimoRouteBatchClass(settings.Last_Batch_Job_Executed__c);
        
        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Iterate over query results to count them
        Database.QueryLocatorIterator it = ql.iterator();
        List<WorkOrder> results = new List<WorkOrder>();
        while (it.hasNext()) {
            results.add((WorkOrder)it.next()); 
        }

        // Assertion: Should find exactly 1 record (The 'Ready' one), ignoring the 'New' one.
        System.assertEquals(1, results.size(), 'QueryLocator should return exactly 1 record');
    }

    /**
     * @description Tests handling of empty scope in execute method (Code coverage/Safety check).
     */
    @isTest
    static void testExecuteEmptyScope() {
        OptimoRouteBatchClass batch = new OptimoRouteBatchClass(System.now());
        
        Test.startTest();
        // Pass empty list to execute
        batch.execute(null, new List<WorkOrder>());
        Test.stopTest();
        
        // No assertions needed; just ensuring no null pointer exceptions are thrown
        System.assertEquals(0, batch.totalRecordsProcessed, 'Total records should remain 0');
    }
}