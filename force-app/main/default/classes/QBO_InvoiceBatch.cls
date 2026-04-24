/**
 * @description Processes "Opem" Invoices and their associated Work Orders for QBO sync.
 * DESIGN PATTERN: Collector-based Batch. Processes Header (Invoice) and children (Work Orders).
 */
public with sharing class QBO_InvoiceBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    // Member variables for tracking and settings
    public Integer totalProcessed = 0;
    public DateTime batchStartTime;
    private List<Id> wIds;

    /**
     * @description Entry point for execution. Fetches batch size from Custom Settings.
     */
    public static void executeQBOBatch() {
        QBO_Batch_Settings__c settings = QBO_Batch_Settings__c.getOrgDefaults();
        
        QBO_InvoiceBatch batch = new QBO_InvoiceBatch();
        // Default to 1 to ensure callout limits are respected for multi-line invoices
        Integer batchSize = (settings.Batch_Job_Size__c != null) ? Integer.valueOf(settings.Batch_Job_Size__c) : 1;
        
        Database.executeBatch(batch, batchSize);
    }

    /**
     * @description Constructor initializes the start time for the sync window.
     */
    public QBO_InvoiceBatch() {
        this.batchStartTime = System.now(); //
    }
    
    public QBO_InvoiceBatch(List<Id> workOrderIds) {
        this.batchStartTime = System.now(); //
        this.wIds = workOrderIds;
    }

    /**
     * @description Queries 'Open' Invoices flagged as 'Ready' by the Step 1 Flow.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        // If Work Orders are selected
        if (this.wIds != null && !this.wIds.isEmpty()) {
    
            // Step 1: Get related Invoice Ids from Work Orders
            Set<Id> invoiceIds = new Set<Id>();
    
            for (WorkOrder wo : [
                SELECT Invoice__c
                FROM WorkOrder
                WHERE Id IN :this.wIds
                AND Invoice__c != null
            ]) {
                invoiceIds.add(wo.Invoice__c);
            }
    
            // Step 2: If no invoices found, return empty query
            if (invoiceIds.isEmpty()) {
                return Database.getQueryLocator([
                    SELECT Id FROM Invoice__c WHERE Id = null
                ]);
            }
    
            // Step 3: Query only relevant invoices
            return Database.getQueryLocator([
                SELECT Id, Name, Account__c
                FROM Invoice__c
                WHERE Id IN :invoiceIds
                AND Ready_for_Integration__c = true
                AND Invoice_Status__c = 'Open'
                AND QBO_Invoice_ID__c = null
            ]);
        }
        
        return Database.getQueryLocator([
            SELECT Id, Name, Account__c 
            FROM Invoice__c 
            WHERE Ready_for_Integration__c = true 
            AND Invoice_Status__c = 'Open'
            AND QBO_Invoice_ID__c = null
        ]);
    }

    /**
     * @description Delegates Invoice processing to the Helper class.
     */
    public void execute(Database.BatchableContext bc, List<Invoice__c> scope) {
        if (scope == null || scope.isEmpty()) return;

        try {
            // Pass the scope to the Helper to build Account-grouped payloads
            QBO_InvoiceHelper.processInvoices(scope, this.wIds);
            totalProcessed += scope.size(); //
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'QBO Sync Error: ' + ex.getMessage());
        }
    }

    /**
     * @description Updates the Custom Setting with the completion timestamp.
     */
    public void finish(Database.BatchableContext bc) {
        QBO_Batch_Settings__c settings = QBO_Batch_Settings__c.getOrgDefaults();
        settings.Last_Batch_Job_Executed__c = this.batchStartTime; //
        upsert settings;

        System.debug('QBO Batch Sync Finished. Records: ' + totalProcessed);
    }
}