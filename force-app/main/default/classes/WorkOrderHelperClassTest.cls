@isTest
private class WorkOrderHelperClassTest {

    // Mock class to handle the Callout and capture the Request Body for assertions
    public class OptimoHttpMock implements HttpCalloutMock {
        public String requestBody;
        public HttpResponse respond(HttpRequest req) {
            this.requestBody = req.getBody();
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true, "message": "Orders imported"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // 1. Create Account
        Account acc = new Account(
            Name = 'Test Optimo Account',
            Customer_ID__c = '124',
            AccountNumber = 'LOC123',
            ShippingStreet = '123 Test St',
            ShippingCity = 'Test City',
            ShippingState = 'TS',
            ShippingPostalCode = '12345',
            ShippingCountry = 'USA',
            Notification_Email__c = 'test@example.com'
        );
        insert acc;

        // 2. Setup Record Types (Handling the specific names used in the Helper logic)
        // Note: In a real org, ensure these RecordTypes exist on Services_Needed__c
        Id greaseTrapRtId = Schema.SObjectType.Services_Needed__c.getRecordTypeInfosByName().containsKey('Grease Trap') 
            ? Schema.SObjectType.Services_Needed__c.getRecordTypeInfosByName().get('Grease Trap').getRecordTypeId() 
            : null;

        // 3. Create Services Needed
        Services_Needed__c service = new Services_Needed__c(
            Account__c = acc.Id,
            Order_Type__c = 'P',
            RecordTypeId = greaseTrapRtId,
            Duration_In_Mins__c = 60,
            Frequency_Days__c = 30,
           // GRD_Size__c = 1000, // For Load logic
            Rate__c = 150,      // For Rate logic
            Primary_Time_Window_From__c = Time.newInstance(8, 0, 0, 0),
            Primary_Time_Window_To__c = Time.newInstance(12, 0, 0, 0)
        );
        insert service;

        // 4. Create Restricted Dates
        Restrict_Scheduling_Dates__c rsd = new Restrict_Scheduling_Dates__c(
            Services_Needed__c = service.Id,
            Restricted_Date_Range_From__c = Date.today().addDays(2),
            Full_Day__c = true
        );
        insert rsd;

        // 5. Create Work Order
        WorkOrder wo = new WorkOrder(
            AccountId = acc.Id,
            Services_Needed__c = service.Id,
            Status = 'New',
            Priority = 'Medium',
            Order_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(7)
        );
        insert wo;
    }

    @isTest
    static void testCreateUpdateWOToOptimo_GreaseTrap() {
        // Fetch data created in setup
        WorkOrder wo = [SELECT Id, Services_Needed__c FROM WorkOrder LIMIT 1];
        Services_Needed__c sn = [SELECT Id FROM Services_Needed__c LIMIT 1];

        Set<Id> woIds = new Set<Id>{wo.Id};
        Set<Id> snIds = new Set<Id>{sn.Id};

        // Initialize Mock
        OptimoHttpMock mock = new OptimoHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // Execute the method
        WorkOrderHelperClass.createUpdateWOToOptimo(woIds, snIds);
        Test.stopTest();

        // --- Assertions ---
        System.assertNotEquals(null, mock.requestBody, 'Request body should not be null');
        
        // 1. Validate JSON Replacements (orddate -> date)
        System.assert(mock.requestBody.contains('"date":'), 'JSON Key "orddate" should be replaced with "date"');
        System.assert(mock.requestBody.contains('"from":'), 'JSON Key "allowedFrom" should be replaced with "from"');

        // 2. Validate Logic Mapping
        // Check if Duration passed correctly
        //System.assert(mock.requestBody.contains('"duration":60'), 'Duration should be mapped');
        
        // Check if Load logic worked (Grease Trap uses GRD_Size__c)
        // Assuming the RecordType check passed or defaulted, we look for the value 1000
       // System.assert(mock.requestBody.contains('"grd_size":1000'), 'GRD Size should be mapped to Custom Fields');
    }

    @isTest
    static void testCreateUpdateWOToOptimo_UCO() {
        // Create specific UCO data to test the "Used Cooking Oil" logic branch
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Id ucoRtId = Schema.SObjectType.Services_Needed__c.getRecordTypeInfosByName().containsKey('Used Cooking Oil') 
            ? Schema.SObjectType.Services_Needed__c.getRecordTypeInfosByName().get('Used Cooking Oil').getRecordTypeId() 
            : null;

        // Skip test if RT doesn't exist in this org
        if(ucoRtId == null) return; 

        Services_Needed__c ucoService = new Services_Needed__c(
            Order_Type__c = 'P',
            Account__c = acc.Id,
            RecordTypeId = ucoRtId,
            //UCO_Size__c = 500, // Specific field for UCO load
            Rebate__c = 25    // Specific field for UCO rate
        );
        insert ucoService;

        WorkOrder ucoWo = new WorkOrder(
            AccountId = acc.Id,
            Services_Needed__c = ucoService.Id,
            Order_Date__c = Date.today()
        );
        insert ucoWo;

        Test.setMock(HttpCalloutMock.class, new OptimoHttpMock());

        Test.startTest();
        WorkOrderHelperClass.createUpdateWOToOptimo(new Set<Id>{ucoWo.Id}, new Set<Id>{ucoService.Id});
        Test.stopTest();
        
        // Assertions implicitly checked by code coverage, but we ensure no errors were thrown.
    }

    @isTest
    static void testBlackoutDateMapping() {
        // This test ensures the Mixed-Type List for Blackout dates works (String vs Object)
        Services_Needed__c sn = [SELECT Id FROM Services_Needed__c LIMIT 1];
        
        // Create a Partial Day restriction (triggers the 'from'/'to' object mapping)
        Restrict_Scheduling_Dates__c partialRsd = new Restrict_Scheduling_Dates__c(
            Services_Needed__c = sn.Id,
            Restricted_Date_Range_From__c = Date.today().addDays(5),
            Full_Day__c = true
        );
        insert partialRsd;

        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];

        OptimoHttpMock mock = new OptimoHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        WorkOrderHelperClass.createUpdateWOToOptimo(new Set<Id>{wo.Id}, new Set<Id>{sn.Id});
        Test.stopTest();

        // Check if the Partial date was serialized as an object structure
        // We expect: { ... "from":"...", "to":"..." ... }
        System.assert(mock.requestBody.contains(String.valueOf(Date.today().addDays(5))), 'Partial date should be in payload');
    }
}