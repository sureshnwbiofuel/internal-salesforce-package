public with sharing class ValidateWOandSyncAPexHandler {

    // Wrapper to send to LWC
    public class FieldWrapper {
        @AuraEnabled public String fieldName {get; set;}
        @AuraEnabled public String fieldValue {get; set;}
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getWORecord(Id woRecordId){
        try {
            WorkOrder wo = [SELECT Id,Account.Name,Contact.Name from WOrkOrder where Id = :woRecordId];

            /*Map<String, String> mapOfWOFieldandValue = new Map<String, String>();
            mapOfWOFieldandValue.put('Account', String.valueOf(wo.Account.Name));
            mapOfWOFieldandValue.put('Contact', String.valueOf(wo.Contact.Name));
            return mapOfWOFieldandValue;*/
            List<FieldWrapper> listOfFields = new List<FieldWrapper>();
            FieldWrapper fieldWrapper = new FieldWrapper();
            fieldWrapper.fieldName = 'Account';
            fieldWrapper.fieldValue = String.valueOf(wo.Account.Name);
            listOfFields.add(fieldWrapper);
            FieldWrapper fieldWrapper1 = new FieldWrapper();
            fieldWrapper1.fieldName = 'Contact';
            fieldWrapper1.fieldValue = String.valueOf(wo.Contact.Name);
            listOfFields.add(fieldWrapper1);
            return listOfFields;
        
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}