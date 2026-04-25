/**
 * @description Selector class for WorkOrder and related custom objects.
 * This class centralizes all SOQL queries required for the Optimo Route integration
 * to ensure consistency and maintainability.
 */

 public with sharing class GetObjectSOQL {

    /**
     * @description Fetches comprehensive WorkOrder details including parent Account 
     * and related Service information. This is used to build the outbound Optimo request.
     * @param setOfReadyWorkOrderIds Set of WorkOrder IDs to retrieve.
     * @return List<WorkOrder> containing fields for routing, scheduling, and customer info.
     */
    public static List<WorkOrder> getWorkOrders(Set<Id> setOfReadyWorkOrderIds) {
        if (setOfReadyWorkOrderIds == null || setOfReadyWorkOrderIds.isEmpty()) {
            return new List<WorkOrder>();
        }
        return [SELECT Id, Status, WorkOrderNumber,Work_Order_Number_Display__c,Priority,Barcode__c,Due_Date__c,Order_Date__c,Grease_Trap_Unit__c,Optimo_Order_Id__c,
                        AccountId, Account.Name,Account.AccountNumber,Account.Location_Check_in_Time__c,Account.Location_Notes__c, 
                        Allowed_Days__c,Account.Internal_Notes__c,Account.Notification_Email__c,Account.Notification_Phone_Number__c,
                        Account.Notification_Preference__c,Alarm_Code__c,Account.County__c,Door_Code__c,Account.Customer_ID__c,
                        Account.shippingStreet,Account.shippingCity,Account.shippingState,Account.shippingPostalCode,Account.shippingCountry,Account.shippinglatitude,Account.shippinglongitude,
                        Services_Needed__c,Services_Needed__r.RecordType.Name,Services_Needed__r.Name,Services_Needed__r.Services_Needed_Number_Display__c,Services_Needed__r.Notification_Email__c , 
                        Services_Needed__r.Notification_Phone_Number__c ,Services_Needed__r.Communication_Preference__c ,Services_Needed__r.Notification_Method__c,
                        Services_Needed__r.Container_Size1__c,Services_Needed__r.Container_Size2__c,Services_Needed__r.Container_Size3__c,
                        Services_Needed__r.Indoor_Outdoor__c,Services_Needed__r.Scheduled_Delivery_Date__c,Services_Needed__r.Daily_Fill_Rate__c,Services_Needed__r.Last_Collected_Gallons__c,
                        Order_Type__c,Duration_In_Mins__c, Skills__c,Vehicle_Features__c,Service_Notes__c,Door_Key__c,
                        Primary_Time_Window_From__c,Primary_Time_Window_To__c,Secondary_Time_Window_From__c,Secondary_Time_Window_To__c,
                        Frequency_Days__c,Connected_Fixture__c,Rate__c,Rebate__c,Volume__c,GRD_Location_Name__c,Container_Size_1__c,Container_Size_2__c,Container_Size_3__c,Indoor_Outdoor__c,
                        GRD_Serial_Number__c,Current_Fill_Level__c
                        from 
                        WorkOrder 
                        where 
                        Id in : setOfReadyWorkOrderIds WITH USER_MODE];
    }

    
    /**
     * @description Lightweight query to retrieve only identifying information for WorkOrders.
     * Typically used during response handling to update status and link Optimo IDs.
     * @param setOfReadyWorkOrderIds Set of WorkOrder IDs.
     * @return List<WorkOrder> with minimal fields.
     */
    public static List<WorkOrder> getWorkOrderNumbers(Set<Id> setOfReadyWorkOrderIds) {
        if (setOfReadyWorkOrderIds == null || setOfReadyWorkOrderIds.isEmpty()) {
            return new List<WorkOrder>();
        }
        return [SELECT Id, Status, WorkOrderNumber, Optimo_Order_Id__c,Work_Order_Number_Display__c
                        from 
                        WorkOrder 
                        where 
                        Id in : setOfReadyWorkOrderIds WITH USER_MODE];
    }

    /**
     * @description Retrieves restricted scheduling dates (Blackout dates) based on the Services Needed.
     * These dates are passed to Optimo to ensure orders aren't scheduled on unavailable days.
     * @param setOfServiceNeededIds Set of IDs from the 'Services_Needed__c' custom object.
     * @return List<Restrict_Scheduling_Dates__c>
     */
    public static List<Restrict_Scheduling_Dates__c> getRestrictSchedules(Set<Id> setOfServiceNeededIds){
        if (setOfServiceNeededIds == null || setOfServiceNeededIds.isEmpty()) {
            return new List<Restrict_Scheduling_Dates__c>();
        }
        return [SELECT Id,Account__c,Services_Needed__c,Restricted_Date_Range_From__c,
                        Restricted_Date_Range_To__c,Full_Day__c 
                        from Restrict_Scheduling_Dates__c 
                        where
                        Services_Needed__c in :setOfServiceNeededIds WITH USER_MODE];
    }
}