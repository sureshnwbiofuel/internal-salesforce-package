public with sharing class QBO_InvoiceBatchController {

    @AuraEnabled
    public static void runBatch(List<Id> workOrderIds) {

        QBO_Batch_Settings__c settings = QBO_Batch_Settings__c.getOrgDefaults();

        Integer batchSize = (settings.Batch_Job_Size__c != null)
            ? Integer.valueOf(settings.Batch_Job_Size__c)
            : 1;

        QBO_InvoiceBatch batch = (workOrderIds != null && !workOrderIds.isEmpty())
            ? new QBO_InvoiceBatch(workOrderIds)
            : new QBO_InvoiceBatch();

        Database.executeBatch(batch, batchSize);
    }
}