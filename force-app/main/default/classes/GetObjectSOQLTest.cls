@isTest
private class GetObjectSOQLTest {

    @testSetup
    static void setupData() {
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
            Rate__c = 100.00
            // Add other mandatory fields here
        );
        insert testService;

        // 3. Create WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            AccountId = testAccount.Id,
            Services_Needed__c = testService.Id,
            Status = 'New',
            Priority = 'Medium',
            Subject = 'Test Work Order'
        );
        insert testWorkOrder;

        // 4. Create Restrict_Scheduling_Dates__c
        Restrict_Scheduling_Dates__c testRestrictedDate = new Restrict_Scheduling_Dates__c(
            Services_Needed__c = testService.Id,
            Account__c = testAccount.Id,
            Restricted_Date_Range_From__c = Date.today(),
            Full_Day__c = true
        );
        insert testRestrictedDate;
    }

    /**
     * @description Tests the main getWorkOrders method which fetches full details.
     */
    @isTest
    static void testGetWorkOrders() {
        // Retrieve the setup data
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Set<Id> workOrderIds = new Set<Id>{ wo.Id };

        Test.startTest();
        List<WorkOrder> results = GetObjectSOQL.getWorkOrders(workOrderIds);
        Test.stopTest();

        // Assertions
        System.assertEquals(1, results.size(), 'Should return exactly one WorkOrder');
        WorkOrder resultWO = results[0];
        
        // Verify Account relationship fields
        System.assertNotEquals(null, resultWO.Account, 'Account relationship should be fetched');
        System.assertEquals('Test Optimo Account', resultWO.Account.Name, 'Account Name should match');
        
        // Verify Services_Needed__c relationship fields
        System.assertNotEquals(null, resultWO.Services_Needed__r, 'Services_Needed__r relationship should be fetched');
    }

    /**
     * @description Tests the lightweight getWorkOrderNumbers method.
     */
    @isTest
    static void testGetWorkOrderNumbers() {
        // Retrieve the setup data
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Set<Id> workOrderIds = new Set<Id>{ wo.Id };

        Test.startTest();
        List<WorkOrder> results = GetObjectSOQL.getWorkOrderNumbers(workOrderIds);
        Test.stopTest();

        // Assertions
        System.assertEquals(1, results.size(), 'Should return one WorkOrder');
        System.assertNotEquals(null, results[0].WorkOrderNumber, 'WorkOrderNumber should be populated');
        
        // Ensure fields NOT in the query are NOT retrieved (sanity check)
        // Accessing a field not queried throws an SObjectException
        Boolean exceptionThrown = false;
        try {
            String accName = results[0].Account.Name;
        } catch (SObjectException e) {
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown, 'Should not retrieve fields that were not requested (like Account.Name)');
    }

    /**
     * @description Tests the retrieval of Restrict_Scheduling_Dates__c.
     */
    @isTest
    static void testGetRestrictSchedules() {
        // Retrieve the setup service
        Services_Needed__c service = [SELECT Id FROM Services_Needed__c LIMIT 1];
        Set<Id> serviceIds = new Set<Id>{ service.Id };

        Test.startTest();
        List<Restrict_Scheduling_Dates__c> results = GetObjectSOQL.getRestrictSchedules(serviceIds);
        Test.stopTest();

        // Assertions
        System.assertEquals(1, results.size(), 'Should return one restricted schedule record');
        System.assertEquals(service.Id, results[0].Services_Needed__c, 'Service ID should match');
        System.assertEquals(true, results[0].Full_Day__c, 'Full Day flag should match');
    }

    /**
     * @description Negative test to ensure empty sets don't cause errors.
     */
    @isTest
    static void testEmptyInputs() {
        Test.startTest();
        List<WorkOrder> woResults = GetObjectSOQL.getWorkOrders(new Set<Id>());
        List<WorkOrder> woNumResults = GetObjectSOQL.getWorkOrderNumbers(new Set<Id>());
        List<Restrict_Scheduling_Dates__c> restResults = GetObjectSOQL.getRestrictSchedules(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, woResults.size(), 'Should return empty list for empty input');
        System.assertEquals(0, woNumResults.size(), 'Should return empty list for empty input');
        System.assertEquals(0, restResults.size(), 'Should return empty list for empty input');
    }
}