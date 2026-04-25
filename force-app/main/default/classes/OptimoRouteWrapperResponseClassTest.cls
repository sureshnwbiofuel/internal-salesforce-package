@isTest
private class OptimoRouteWrapperResponseClassTest {

    /**
     * @description Tests that a valid JSON response string is correctly deserialized
     * into the wrapper class fields. This is the primary use case for this class.
     */
    @isTest
    static void testDeserialization() {
        // 1. Simulate a JSON response from Optimo Route
        String jsonResponse = '{' +
            '"success": true,' +
            '"code": "SUCCESS",' +
            '"message": "Orders processed",' +
            '"orders": [' +
                '{' +
                    '"orderNo": "WO-001",' +
                    '"id": "OPT-1001",' +
                    '"success": true' +
                '},' +
                '{' +
                    '"orderNo": "WO-002",' +
                    '"id": null,' +
                    '"success": false' +
                '}' +
            ']' +
        '}';

        Test.startTest();
        // 2. Deserialize JSON into the Apex Class
        OptimoRouteWrapperResponseClass wrapper = (OptimoRouteWrapperResponseClass)JSON.deserialize(jsonResponse, OptimoRouteWrapperResponseClass.class);
        Test.stopTest();

        // 3. Assert Main Class Fields
        System.assertEquals(true, wrapper.success, 'Overall success should be true');
        System.assertEquals('SUCCESS', wrapper.code, 'Response code should match');
        System.assertEquals('Orders processed', wrapper.message, 'Message should match');
        System.assertEquals(2, wrapper.orders.size(), 'Should contain 2 order results');

        // 4. Assert Inner Class Fields (Success Case)
        OptimoRouteWrapperResponseClass.cls_orders order1 = wrapper.orders[0];
        System.assertEquals('WO-001', order1.orderNo, 'Order Number should match');
        System.assertEquals('OPT-1001', order1.id, 'Optimo ID should match');
        System.assertEquals(true, order1.success, 'Individual order success should be true');

        // 5. Assert Inner Class Fields (Failure Case)
        OptimoRouteWrapperResponseClass.cls_orders order2 = wrapper.orders[1];
        System.assertEquals('WO-002', order2.orderNo, 'Order Number should match');
        System.assertEquals(null, order2.id, 'Optimo ID should be null for failed order');
        System.assertEquals(false, order2.success, 'Individual order success should be false');
    }

    /**
     * @description Tests direct instantiation to ensure constructors and field visibility work 
     * (e.g. if you ever needed to create this object manually in Apex).
     */
    @isTest
    static void testDirectInstantiation() {
        // Instantiate main class
        OptimoRouteWrapperResponseClass wrapper = new OptimoRouteWrapperResponseClass();
        wrapper.success = false;
        wrapper.code = 'ERR_TEST';
        wrapper.message = 'Test Error';
        wrapper.orders = new List<OptimoRouteWrapperResponseClass.cls_orders>();

        // Instantiate inner class
        OptimoRouteWrapperResponseClass.cls_orders order = new OptimoRouteWrapperResponseClass.cls_orders();
        order.orderNo = 'WO-999';
        order.id = 'OPT-999';
        order.success = true;

        wrapper.orders.add(order);

        // Assertions
        System.assertEquals('ERR_TEST', wrapper.code, 'Code assignment should work');
        System.assertEquals(1, wrapper.orders.size(), 'List assignment should work');
        System.assertEquals('WO-999', wrapper.orders[0].orderNo, 'Inner class assignment should work');
    }
}