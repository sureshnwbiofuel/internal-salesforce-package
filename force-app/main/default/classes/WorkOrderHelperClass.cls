/**
 * @description Helper class to handle the logic of preparing and sending Work Order data to Optimo.
 */

 public with sharing class WorkOrderHelperClass {

    /**
     * @description Orchestrates the fetching, wrapping, and callout for WorkOrders.
     * @param workOrderIds Set of WorkOrder IDs to process.
     * @param serviceNeededIds Set of Service Needed IDs for blackout date mapping.
     */
    
    public static void createUpdateWOToOptimo(Set<Id> workOrderIds, Set<Id> serviceNeededIds) {

        // 1. Fetch Data
        List<WorkOrder> workOrders = GetObjectSOQL.getWorkOrders(workOrderIds);
        List<Restrict_Scheduling_Dates__c> restrictedDates = GetObjectSOQL.getRestrictSchedules(serviceNeededIds);

        // 2. Map Restricted Dates by Service ID
        Map<Id, List<Restrict_Scheduling_Dates__c>> rsdMap = mapRestrictedDates(restrictedDates);

       // Map<Id,List<Restrict_Scheduling_Dates__c>> mapOfWOandRSD = new Map<Id,List<Restrict_Scheduling_Dates__c>>();
      /*  for(Restrict_Scheduling_Dates__c rsd : listOfRSDs){
            if(mapOfWOandRSD.containsKey(rsd.Services_Needed__c)){
                mapOfWOandRSD.get(rsd.Services_Needed__c).add(rsd);
            }else{
                mapOfWOandRSD.put(rsd.Services_Needed__c,new List<Restrict_Scheduling_Dates__c>{rsd});
            }
        }*/

        // 3. Build Wrapper List
        OptimoRouteWrapperClass rootWrapper = new OptimoRouteWrapperClass();
        rootWrapper.orders = new List<OptimoRouteWrapperClass.cls_orders>();

        for (WorkOrder wo : workOrders) {
            rootWrapper.orders.add(createOrderWrapper(wo, rsdMap.get(wo.Services_Needed__c)));
        }

        // 4. Serialize and Perform Callout
        // Using chained replace to match Optimo's specific JSON key requirements
        String reqBody = JSON.serialize(rootWrapper)
                             .replace('orddate', 'date')
                             .replace('allowedFrom', 'from')
                             .replace('allowedTo', 'to');

        HttpResponse res = APICallOutsClass.optimoRouteCallOut(reqBody, workOrderIds);

        // 5. Delegate Response Handling
        if (res != null) {
            IntegrationResponseHandler.handleOptimoResponse(res, workOrderIds);
        }  
    }

    /**
     * @description Groups restricted dates by Service Needed ID for efficient lookups.
     */
    private static Map<Id, List<Restrict_Scheduling_Dates__c>> mapRestrictedDates(List<Restrict_Scheduling_Dates__c> rsdList) {
        Map<Id, List<Restrict_Scheduling_Dates__c>> rsdMap = new Map<Id, List<Restrict_Scheduling_Dates__c>>();
        for (Restrict_Scheduling_Dates__c rsd : rsdList) {
            if (!rsdMap.containsKey(rsd.Services_Needed__c)) {
                rsdMap.put(rsd.Services_Needed__c, new List<Restrict_Scheduling_Dates__c>());
            }
            rsdMap.get(rsd.Services_Needed__c).add(rsd);
        }
        return rsdMap;
    }

    /**
     * @description Maps a single WorkOrder record to the Optimo Order Wrapper.
     */
    private static OptimoRouteWrapperClass.cls_orders createOrderWrapper(WorkOrder wo, List<Restrict_Scheduling_Dates__c> rsdList) {
        OptimoRouteWrapperClass.cls_orders order = new OptimoRouteWrapperClass.cls_orders();
        
        // Basic Mappings
        order.operation = 'SYNC';
        order.Id = wo.Optimo_Order_Id__c;
        //order.orderNo = wo.WorkOrderNumber; // change it to display
        order.orderNo = wo.Work_Order_Number_Display__c.substringBetween('>', '</a>');
        order.orddate = String.valueOf(wo.Order_Date__c);
        order.duration = wo.Duration_In_Mins__c != null ? Integer.valueOf(wo.Duration_In_Mins__c) : null;
        order.priority = wo.Priority;
        order.type = wo.Order_Type__c;
        //order.notes = wo.Account.Internal_Notes__c;
        order.email = wo.Services_Needed__r.Notification_Email__c;
        order.phone = wo.Services_Needed__r.Notification_Phone_Number__c;
        order.notificationPreference = wo.Services_Needed__r.Communication_Preference__c;

        // Dynamic load2 mapping based on Record Type
        //order.load2 = getLoadRequirement(wo);
        order.load2 = wo.Volume__c != null ? Integer.valueOf(wo.Volume__c) : null ; //mapped all the sizes into volume

        // Map Allowed Weekdays (Multi-select picklist)
        if (String.isNotBlank(wo.Allowed_Days__c)) {
            order.allowedWeekdays = wo.Allowed_Days__c.toLowerCase().split(';');
        }

        // Map Allowed Date Window (Current Week)
        order.allowedDates = new OptimoRouteWrapperClass.cls_allowedDates();
        order.allowedDates.allowedFrom = String.valueOf(wo.Order_Date__c?.toStartOfWeek());
        order.allowedDates.allowedTo = String.valueOf(wo.Order_Date__c?.toStartOfWeek().addDays(6));
        
        // Map Skills & Vehicle Features
        order.skills = wo.Skills__c?.split(';');
        order.vehicleFeatures = wo.Vehicle_Features__c?.split(';');

        // Sub-object Mappings
        order.location = mapLocation(wo);
        order.timeWindows = mapTimeWindows(wo);
        order.blackoutDates = mapBlackoutDates(rsdList);
        order.barcode = mapBarcode(wo);
        order.customFields = mapCustomFields(wo);

        return order;
    }

    /**
     * @description Helper to determine load requirement based on Work Order Type.
     */
   /* private static Integer getLoadRequirement(WorkOrder wo) {
        String rtName = wo.Services_Needed__r.RecordType.Name;
        if (rtName == 'Grease Trap' || rtName == 'Interceptor'  || rtName == 'Waste Run') { return wo.Services_Needed__r.GRD_Size__c != null ? Integer.valueOf(wo.Services_Needed__r.GRD_Size__c) : null ;} 
        if (rtName == 'Used Cooking Oil'){ return wo.Services_Needed__r.UCO_Size__c != null ? Integer.valueOf(wo.Services_Needed__r.UCO_Size__c) : null ;}
        if (rtName == 'Drain Cleaning'){return wo.Services_Needed__r.HYD_Size__c != null ? Integer.valueOf(wo.Services_Needed__r.HYD_Size__c) : null ;}
        return null;
    }*/

    /**
     * @description Helper to determine load requirement based on Work Order Type.
     */
    private static Integer getRate(WorkOrder wo) {
        String rtName = wo.Services_Needed__r.RecordType.Name;
        if (rtName == 'Grease Trap' || rtName == 'Drain Cleaning' || rtName == 'Interceptor'  || rtName == 'Waste Run') { return wo.Rate__c != null ? Integer.valueOf(wo.Rate__c) : null ;} 
        if (rtName == 'Used Cooking Oil'){ return wo.Rebate__c != null ? Integer.valueOf(wo.Rebate__c) : null ;}
        return null;
    }

    /**
     * @description Maps Account fields to the Optimo Location object.
     */
    private static OptimoRouteWrapperClass.cls_location mapLocation(WorkOrder wo) {
        OptimoRouteWrapperClass.cls_location loc = new OptimoRouteWrapperClass.cls_location();
        loc.locationNo = wo.Account.AccountNumber;
        loc.locationName = wo.Account.Name;
        loc.latitude = wo.Account.shippinglatitude;
        loc.longitude = wo.Account.shippinglongitude;
        loc.notes = wo.Account.Location_Notes__c;
        
        // Address formatting
        loc.address = String.format('{0}, {1}, {2}, {3}, {4}', new String[]{
            wo.Account.shippingStreet, wo.Account.shippingCity, 
            wo.Account.shippingState, wo.Account.shippingPostalCode, wo.Account.shippingCountry
        });

        // Safe conversion of Time to Integer (representing hour or minutes)
        loc.checkInTime = wo.Account.Location_Check_in_Time__c != null ? Integer.valueOf(wo.Account.Location_Check_in_Time__c) : null;
        
        return loc;
    }

    /**
     * @description Maps primary and secondary time windows.
     */
    private static List<OptimoRouteWrapperClass.cls_timeWindows> mapTimeWindows(WorkOrder wo) {
        List<OptimoRouteWrapperClass.cls_timeWindows> windows = new List<OptimoRouteWrapperClass.cls_timeWindows>();
        
        // Primary Window
        if (wo.Primary_Time_Window_From__c != null && wo.Primary_Time_Window_To__c != null ) {
            OptimoRouteWrapperClass.cls_timeWindows tw = new OptimoRouteWrapperClass.cls_timeWindows();
            tw.twFrom = String.valueOf(wo.Primary_Time_Window_From__c).substring(0, 5);
            tw.twTo = String.valueOf(wo.Primary_Time_Window_To__c).substring(0, 5);
            windows.add(tw);
        }

        // Secondary Window
        if (wo.Secondary_Time_Window_From__c != null && wo.Secondary_Time_Window_To__c != null) {
            OptimoRouteWrapperClass.cls_timeWindows tw = new OptimoRouteWrapperClass.cls_timeWindows();
            tw.twFrom = String.valueOf(wo.Secondary_Time_Window_From__c).substring(0, 5);
            tw.twTo = String.valueOf(wo.Secondary_Time_Window_To__c).substring(0, 5);
            windows.add(tw);
        }
        return windows;
    }

    /**
     * @description Formats Blackout dates into the mixed-type list Optimo expects.
     */
    private static List<Object> mapBlackoutDates(List<Restrict_Scheduling_Dates__c> rsdList) {
        List<Object> blackouts = new List<Object>();
        if (rsdList == null) return blackouts;

        for (Restrict_Scheduling_Dates__c rsd : rsdList) {
            if (rsd.Full_Day__c) {
                blackouts.add(rsd.Restricted_Date_Range_From__c);
            } else {
                blackouts.add(new Map<String, String>{
                    'from' => String.valueOf(rsd.Restricted_Date_Range_From__c),
                    'to' => String.valueOf(rsd.Restricted_Date_Range_To__c)
                });
            }
        }
        return blackouts;    
    }

    /**
     * @description Barcode.
     */
    private static List<OptimoRouteWrapperClass.cls_barcode> mapBarcode(WorkOrder wo) {
        List<OptimoRouteWrapperClass.cls_barcode> barcodes = new List<OptimoRouteWrapperClass.cls_barcode>();
        
        // Primary Window
        if (wo.Barcode__c != null) {
            OptimoRouteWrapperClass.cls_barcode bar = new OptimoRouteWrapperClass.cls_barcode();
            bar.barcode = wo.Barcode__c;
            barcodes.add(bar);
        }
        return barcodes;
    }

    /**
     * @description Maps technical and business-specific custom fields.
     */
    private static OptimoRouteWrapperClass.cls_customFields mapCustomFields(WorkOrder wo) {
        OptimoRouteWrapperClass.cls_customFields cf = new OptimoRouteWrapperClass.cls_customFields();
        cf.door_key = wo.Door_Key__c != null ? wo.Door_Key__c : null;
        cf.alarm_code = wo.Alarm_Code__c;
        //cf.connected_fixture = wo.Connected_Fixture__c;
        cf.unit = wo.Connected_Fixture__c;
        cf.county = wo.Account.County__c;
        cf.door_code = wo.Door_Code__c != null ? wo.Door_Code__c : null;
        //cf.grease_trap_unit = wo.Grease_Trap_Unit__c; Removed as part of P1-31
        cf.service_notes = wo.Service_Notes__c;
       // cf.rate = wo.Services_Needed__r.Rate__c != null ? Integer.valueOf(wo.Services_Needed__r.Rate__c) : null;
        cf.rate =  getRate(wo);
        cf.unit_location = wo.GRD_Location_Name__c; // mapping changed from grd_physical_location to unit_location, P1-31
        cf.grd_serial_number = wo.GRD_Serial_Number__c;
        //cf.grd_size = wo.Volume__c != null ? Integer.valueOf(wo.Volume__c) : null;
        cf.frequency = wo.Frequency_Days__c != null ? Integer.valueOf(wo.Frequency_Days__c) : null;
        cf.due_date = wo.Due_Date__c != null ? String.valueOf(wo.Due_Date__c) : null;
        cf.qbo_id = wo.Account.Customer_ID__c ;
        //cf.services_needed_number = wo.Services_Needed__r.Name ; // changed it to Display
        cf.services_needed_number = wo.Services_Needed__r.Services_Needed_Number_Display__c.substringBetween('>', '</a>') ;
        cf.notification_method = wo.Services_Needed__r.Notification_Method__c;
        cf.container_size_1 = wo.Container_Size_1__c != null ? getPickListLabel(WorkOrder.SObjectType, 'Container_Size_1__c', wo.Container_Size_1__c) : null;
        cf.container_size_2 = wo.Container_Size_2__c != null ? getPickListLabel(WorkOrder.SObjectType, 'Container_Size_2__c', wo.Container_Size_2__c) : null;
        cf.container_size_3 = wo.Container_Size_3__c != null ? getPickListLabel(WorkOrder.SObjectType, 'Container_Size_3__c', wo.Container_Size_3__c) : null;
        cf.uco_container_location = wo.Indoor_Outdoor__c != null ? wo.Indoor_Outdoor__c : null;
        cf.scheduled_delivery_date = wo.Services_Needed__r.Scheduled_Delivery_Date__c != null ? String.valueOf(wo.Services_Needed__r.Scheduled_Delivery_Date__c) : null;
        cf.daily_fill_rate = wo.Services_Needed__r.Daily_Fill_Rate__c != null ? Integer.valueOf(wo.Services_Needed__r.Daily_Fill_Rate__c) : null;
        cf.last_collected_gallons = wo.Services_Needed__r.Last_Collected_Gallons__c != null ? Integer.valueOf(wo.Services_Needed__r.Last_Collected_Gallons__c) : null;
        cf.current_fill_level = wo.Current_Fill_Level__c != null ? Integer.valueOf(wo.Current_Fill_Level__c) : null;
        return cf;
    }

    /**
     * @description GetPickListLabel
     */
    private static String getPickListLabel(Schema.SObjectType objToken, String fieldName, String targetApiName) {
        String targetLabel = '';

        // 1. Describe the field using the token and field name
        Schema.DescribeFieldResult fieldResult = objToken.getDescribe().fields.getMap().get(fieldName).getDescribe();

        // 2. Get the list of picklist entries
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();

        // 3. Search for the match
        for(Schema.PicklistEntry entry : ple) {
            if(entry.getValue().equalsIgnoreCase(targetApiName)) {
                targetLabel = entry.getLabel();
            }
        } 
        return targetLabel;
    }
}