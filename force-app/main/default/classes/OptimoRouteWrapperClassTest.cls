@isTest
private class OptimoRouteWrapperClassTest {

    /**
     * @description Tests the instantiation of the main class and all inner classes,
     * ensuring that all fields can be written to and read from.
     */
    @isTest
    static void testWrapperStructure() {
        // 1. Initialize Main Wrapper
        OptimoRouteWrapperClass wrapper = new OptimoRouteWrapperClass();
        wrapper.orders = new List<OptimoRouteWrapperClass.cls_orders>();

        // 2. Initialize Order
        OptimoRouteWrapperClass.cls_orders order = new OptimoRouteWrapperClass.cls_orders();
        order.operation = 'SYNC';
        order.orderNo = 'WO-1001';
        order.orddate = '2023-10-01';
        order.duration = 60;
        order.priority = 'H';
        order.type = 'Service';
        order.notes = 'Entry at back';
        order.email = 'test@example.com';
        order.phone = '555-0199';
        order.notificationPreference = 'email';
        order.load3 = 10;
        
        // 3. Initialize Location
        OptimoRouteWrapperClass.cls_location loc = new OptimoRouteWrapperClass.cls_location();
        loc.locationNo = 'ACC-001';
        loc.address = '123 Main St';
        loc.locationName = 'Test Biz';
        loc.latitude = 34.05;
        loc.longitude = -118.25;
        loc.checkInTime = 5;
        loc.notes = 'Gate code 1234';
        order.location = loc;

        // 4. Initialize Time Windows
        OptimoRouteWrapperClass.cls_timeWindows tw = new OptimoRouteWrapperClass.cls_timeWindows();
        tw.twFrom = '08:00';
        tw.twTo = '12:00';
        order.timeWindows = new List<OptimoRouteWrapperClass.cls_timeWindows>{tw};

        // 5. Initialize Allowed Dates
        OptimoRouteWrapperClass.cls_allowedDates allowed = new OptimoRouteWrapperClass.cls_allowedDates();
        allowed.allowedFrom = '2023-10-01';
        allowed.allowedTo = '2023-10-31';
        order.allowedDates = allowed;

        // 6. Initialize Custom Fields
        OptimoRouteWrapperClass.cls_customFields cf = new OptimoRouteWrapperClass.cls_customFields();
        cf.door_key = '1234';
        cf.alarm_code = 'ALARM';
        cf.unit = 'Sink';
        cf.county = 'Orange';
        cf.door_code = '9999';
        cf.grease_trap_unit = 'Large';
        cf.service_notes = 'Clean well';
        cf.rate = 100;
        //cf.grd_physical_location = 'Kitchen';
        cf.grd_serial_number = 'SN-555';
        cf.grd_size = 50;
        cf.frequency = 30;
        cf.due_date = '2023-11-01';
        order.customFields = cf;

        // 7. Initialize Lists
        order.allowedWeekdays = new List<String>{'Mon', 'Tue'};
        order.skills = new List<String>{'Plumbing'};
        order.vehicleFeatures = new List<String>{'Lift Gate'};

        // 8. Add Order to Wrapper
        wrapper.orders.add(order);

        // --- ASSERTIONS ---
        System.assertEquals(1, wrapper.orders.size(), 'Should contain 1 order');
        System.assertEquals('WO-1001', wrapper.orders[0].orderNo, 'Order Number should match');
        System.assertEquals('ACC-001', wrapper.orders[0].location.locationNo, 'Location Number should match');
        System.assertEquals('08:00', wrapper.orders[0].timeWindows[0].twFrom, 'Time Window should match');
        System.assertEquals('1234', wrapper.orders[0].customFields.door_key, 'Custom field Door Key should match');
    }

    /**
     * @description Tests the Blackout Dates logic specifically because it uses List<Object>
     * to handle mixed types (Date Strings or Date Range Objects).
     */
    @isTest
    static void testBlackoutDatesPolymorphism() {
        OptimoRouteWrapperClass.cls_orders order = new OptimoRouteWrapperClass.cls_orders();
        order.blackoutDates = new List<Object>();

        // Case A: Blackout date as a simple String
        order.blackoutDates.add('2023-12-25');

        // Case B: Blackout date as a Range Object
        OptimoRouteWrapperClass.cls_blackoutDates range = new OptimoRouteWrapperClass.cls_blackoutDates();
        range.blackfrom = '2023-12-30';
        range.blackto = '2024-01-01';
        order.blackoutDates.add(range);

        // Assertions
        System.assertEquals(2, order.blackoutDates.size(), 'Should hold both String and Object types');
        System.assertEquals('2023-12-25', order.blackoutDates[0], 'First element should be string');
        
        OptimoRouteWrapperClass.cls_blackoutDates retrievedRange = (OptimoRouteWrapperClass.cls_blackoutDates)order.blackoutDates[1];
        System.assertEquals('2023-12-30', retrievedRange.blackfrom, 'Range object should be retrievable');
    }

    /**
     * @description Verifies that the object can be serialized to JSON, ensuring field visibility.
     */
    @isTest
    static void testJsonSerialization() {
        OptimoRouteWrapperClass wrapper = new OptimoRouteWrapperClass();
        wrapper.orders = new List<OptimoRouteWrapperClass.cls_orders>();
        
        OptimoRouteWrapperClass.cls_orders order = new OptimoRouteWrapperClass.cls_orders();
        order.orderNo = 'TEST-JSON';
        wrapper.orders.add(order);

        Test.startTest();
        String jsonString = JSON.serialize(wrapper);
        Test.stopTest();

        System.assert(jsonString.contains('TEST-JSON'), 'JSON string should contain the order number');
        System.assert(jsonString.contains('orders'), 'JSON string should contain the root key "orders"');
    }
}