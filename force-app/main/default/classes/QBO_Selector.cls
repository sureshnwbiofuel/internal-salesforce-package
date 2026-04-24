/**
 * @description Consolidated Selector to fetch WorkOrders and Parent Details in one call.
 */
public with sharing class QBO_Selector {

    public static List<WorkOrder> getWorkOrdersForInvoices(Set<Id> invoiceIds) {
        return [SELECT Id, Invoice__c, Invoice__r.Name,
                Account.Name,Account.Customer_ID__c,Account.Payment_Term__c,Account.Billing_Email__c,Account.ShippingState,
                Services_Needed__r.RecordType.Name,Order_Date__c,Volume__c,Rate__c,Connected_Fixture__c,Service_Duration_In_Mins__c
                FROM WorkOrder 
                WHERE Invoice__c IN :invoiceIds ];
    }
    
    public static List<WorkOrder> getWorkOrdersById(List<Id> wIds) {
        return [SELECT Id, Invoice__c, Invoice__r.Name,
                Account.Name,Account.Customer_ID__c,Account.Payment_Term__c,Account.Billing_Email__c,Account.ShippingState,
                Services_Needed__r.RecordType.Name,Order_Date__c,Volume__c,Rate__c,Connected_Fixture__c,Service_Duration_In_Mins__c
                FROM WorkOrder 
                WHERE Id IN :wIds ];
    }
    
/**
 * @description Fetches all relevant mappings for Terms and Classes to prevent SOQL in loops.
 */
    public static Map<String, String> getIntegrationMappings(Set<String> terms,Set<String> classes,Set<String> items) {
        
        Map<String, String> integrationQBOIdMap = new Map<String, String>();
        Set<String> rts = new Set<String>();
        Set<String> volumes = new Set<String>();
        Set<Decimal> rates = new Set<Decimal>();
        
        for(String item : items){
            rts.add('%'+item.split('_')[0]+'%');
            volumes.add(item.split('_')[1]);
            rates.add(Decimal.valueOf(item.split('_')[2]));
        }
        
        system.debug(rts+'_'+volumes+'_'+rates);
        
        List<Integration_Mapping__c> intMap = [SELECT Id,Name, QBO_ID__c, Category__c, Full_Name__c, 
                                          Description__c, Unit_Price__c 
                                        FROM Integration_Mapping__c 
                                        WHERE Is_Active__c = true AND ( (Category__c = 'Term' AND Name IN :terms)
                                        OR (Category__c = 'Class' AND Name IN :classes)
                                        OR (Category__c = 'Item' AND Name LIKE :rts AND Description__c IN :volumes 
                                            AND Unit_Price__c IN :rates) )];
                                            
        for(Integration_Mapping__c m : intMap){
            String itemName;
            if(m.name.contains('Interceptor') || m.name.contains('INT')){
                    itemName = 'Interceptor';
                }else if(m.name.contains('Grease Trap')){
                    itemName = 'Grease Trap';
                }else if(m.name.contains('Waste Run')){
                    itemName = 'Waste Run';
                }else if(m.name.contains('Drain Cleaning') || m.name.contains('HYD')){
                    itemName = 'Drain Cleaning';
                }else{
                    itemName = 'Used Cooking Oil';
                }
            
            if(m.Category__c == 'Term' || m.Category__c == 'Class') {
                integrationQBOIdMap.put(m.Name, m.QBO_ID__c);
            }else{
                integrationQBOIdMap.put(itemName+'_'+ m.Description__c + '_' + m.Unit_Price__c, m.Full_Name__c + '_' +m.QBO_ID__c );
            }
        }                                          
        return integrationQBOIdMap;
    }
}