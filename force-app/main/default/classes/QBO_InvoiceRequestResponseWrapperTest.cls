/**
 * @description Test class for QBO_InvoiceRequestWrapper and QBO_InvoiceResponseWrapper.
 * Ensures that the JSON serialization matches Mulesoft requirements and 
 * deserialization correctly handles QBO response structures.
 */

@IsTest
private class QBO_InvoiceRequestResponseWrapperTest {
    
    /**
     * @description Validates the serialization of the Invoice Request.
     */
    
    @IsTest
    static void testRequestSerialization() {
  // 1. Setup Request Data structure
        QBO_InvoiceRequestWrapper req = new QBO_InvoiceRequestWrapper();
        QBO_InvoiceRequestWrapper.InPayload payload = new QBO_InvoiceRequestWrapper.InPayload();
        payload.DocNumber = 'test-pradp-2';
        payload.EmailStatus = 'NeedToSend';
        
        // 2. Setup Line Item with ClassRef and 15-min logic
        payload.Line = new List<QBO_InvoiceRequestWrapper.Line>();
        QBO_InvoiceRequestWrapper.Line line1 = new QBO_InvoiceRequestWrapper.Line();
        line1.LineNum = 1;
        line1.Amount = 512.50; 
        
        QBO_InvoiceRequestWrapper.SalesItemLineDetail detail1 = new QBO_InvoiceRequestWrapper.SalesItemLineDetail();
        detail1.ServiceDate = '2026-04-05'; 
        detail1.Qty = 1.25; // Represents 75 minutes of service
        detail1.UnitPrice = 410.00;
        
        QBO_InvoiceRequestWrapper.ClassRef cls1 = new QBO_InvoiceRequestWrapper.ClassRef();
        cls1.value = '1201547';
        cls1.name = 'Dishwasher';
        detail1.ClassRef = cls1;
        
        line1.SalesItemLineDetail = detail1;
        payload.Line.add(line1);
        req.inPayload = payload;
        
        // 3. Execution
        Test.startTest();
        String jsonReq = req.toJson();
        
        // Deserializing to a Map to perform deep-node assertions
        Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(jsonReq);
        Map<String, Object> resPayload = (Map<String, Object>)root.get('inPayload');
        List<Object> lines = (List<Object>)resPayload.get('Line');
        Map<String, Object> firstLine = (Map<String, Object>)lines[0];
        Map<String, Object> firstLineDetail = (Map<String, Object>)firstLine.get('SalesItemLineDetail');
        Map<String, Object> classRefNode = (Map<String, Object>)firstLineDetail.get('ClassRef');
        Test.stopTest();
        
        // 4. Verification with Assert.areEqual
        Assert.areEqual('test-pradp-2', (String)resPayload.get('DocNumber'), 'DocNumber mapping failed.');
        Assert.areEqual(512.50, (Decimal)firstLine.get('Amount'), 'Total Line Amount calculation failed.');
        Assert.areEqual('1201547', (String)classRefNode.get('value'), 'ClassRef QBO ID mapping failed.');
        Assert.areEqual('Dishwasher', (String)classRefNode.get('name'), 'ClassRef Name mapping failed.');
        
        // Ensure OperationType is NOT present (removed for Mulesoft layer)
        Assert.isFalse(jsonReq.contains('operationType'), 'Payload should not contain operationType.');
        // Ensure WO-Number is NOT present in the line item description
        Assert.isFalse(jsonReq.contains('WO-Number'), 'Payload line should not contain WO-Number.');
    }

    /**
     * @description Validates the deserialization of the QBO Response.
     */
    @IsTest
    static void testResponseDeserialization() {
        // Mock JSON response matching the QBO structure
        String mockResponse = '{' +
            '"Invoice": {' +
                '"Id": "127806",' +
                '"DocNumber": "test-pradp-2",' +
                '"TotalAmt": 787.50,' +
                '"Balance": 787.50' +
            '},' +
            '"time": "2026-04-03T23:29:37.930-07:00"' +
        '}';
        
        Test.startTest();
        QBO_InvoiceResponseWrapper res = QBO_InvoiceResponseWrapper.parse(mockResponse);
        Test.stopTest();
        
        // Verification
        Assert.areEqual('127806', res.Invoice.Id, 'QBO Invoice ID mapping failed.');
        Assert.areEqual(787.50, res.Invoice.TotalAmt, 'Total Amount mapping failed.');
        Assert.areEqual('2026-04-03T23:29:37.930-07:00', res.time_x, 'Time mapping (reserved keyword handling) failed.');
    }
}