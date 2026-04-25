/**
 * @description Wrapper class for the Optimo Route API request payload.
 * This class structure mimics the JSON schema required by Optimo.
 * * NOTE: Some fields use non-standard names (e.g., orddate) to avoid 
 * reserved keyword conflicts in Apex. These are handled via string replacement 
 * or mapping in the calling service.
 */
public with sharing class OptimoRouteWrapperClass {
    
    // Top-level property containing the list of orders
    public List<cls_orders> orders {get; set;}

    /**
     * @description Represents a single Order in Optimo Route.
     */
    public class cls_orders {
        public String id {get; set;}                // Unique OptimoRoute Identifier
        public String operation {get; set;}           // SYNC, DELETE, etc.
        public String orderNo {get; set;}             // Unique Salesforce Identifier (WorkOrderNumber)
        public String orddate {get; set;}             // Replaced with "date" during serialization
        public Integer duration {get; set;}           // Service duration in minutes
        public String priority {get; set;}            // Priority level (e.g., H, M, L)
        public String type {get; set;}                // Order type
        public String notes {get; set;}               // Internal account notes
        public String email {get; set;}               // Customer notification email
        public String phone {get; set;}               // Customer notification phone
        public String notificationPreference {get; set;} // email, sms, etc.
        public Integer load3 {get; set;}              // Capacity/Volume requirement
        public Integer load2 {get; set;}              // Capacity/Volume requirement
        
        // Complex Objects
        public cls_location location {get; set;}
        public List<cls_timeWindows> timeWindows {get; set;}
        public cls_allowedDates allowedDates {get; set;} 
        public cls_customFields customFields {get; set;}

        // Collections
        public List<String> allowedWeekdays {get; set;}
        public List<String> skills {get; set;}
        public List<String> vehicleFeatures {get; set;}
        
        /**
         * @description Blackout dates can be a List of Strings (dates) 
         * or a List of Objects (Date ranges). Using List<Object> for flexibility.
         */
        public List<Object> blackoutDates {get; set;} 

        public List<cls_barcode> barcode {get; set;} 
    }

    /**
     * @description Represents the physical location/address of the order.
     */
    public class cls_location {
        public String locationNo {get; set;}      // Unique ID for the location (AccountNumber)
        public String address {get; set;}         // Full formatted address string
        public String locationName {get; set;}    // Business/Account Name
        public Double latitude {get; set;}        // GPS Latitude
        public Double longitude {get; set;}       // GPS Longitude
        public Integer checkInTime {get; set;}    // Minutes required for check-in
        public String notes {get; set;}           // Location-specific notes
    }

    /**
     * @description Defines specific time slots for the service.
     */
    public class cls_timeWindows {
        public String twFrom {get; set;}          // Format "HH:mm"
        public String twTo {get; set;}            // Format "HH:mm"
    }

    /**
     * @description Range of dates where the order is allowed to be scheduled.
     */
    public class cls_allowedDates {
        public String allowedFrom {get; set;}     // Replaced with "from" during serialization
        public String allowedTo {get; set;}       // Replaced with "to" during serialization
    }

    /**
     * @description Used specifically for blackout date ranges.
     */
    public class cls_blackoutDates {
        public String blackfrom {get; set;}       // Mapping for 'from'
        public String blackto {get; set;}         // Mapping for 'to'
    }

    public class cls_barcode {
        public String barcode {get; set;}    
    }

    /**
     * @description Custom metadata fields specific to the business logic.
     */
    public class cls_customFields {
        public String door_key {get; set;}
        public String alarm_code {get; set;}
       // public String connected_fixture {get; set;}
        public String unit {get; set;}  //connected_fixture
        public String county {get; set;}
        public String door_code {get; set;}
        public String grease_trap_unit {get; set;}
        public String service_notes {get; set;}
        public Integer rate {get; set;}
        public String unit_location {get; set;} //mapping changed from grd_physical_location to unit_location, P1-31
        public String grd_serial_number {get; set;}
        public Integer grd_size {get; set;}
        public Integer frequency {get; set;}
        public String due_date {get; set;}
        public String qbo_id {get; set;}
        public String services_needed_number {get; set;}
        //public String phone_number  {get; set;}
        public String notification_method {get; set;}
        //public String secondary_time_window {get; set;}
        public String container_size_1 {get; set;}
        public String container_size_2 {get; set;}
        public String container_size_3 {get; set;}
        public String uco_container_location {get; set;}
        public String scheduled_delivery_date {get; set;}
        public Integer daily_fill_rate {get; set;}
        public Integer last_collected_gallons {get; set;}
        public Integer current_fill_level {get; set;}
    }
}