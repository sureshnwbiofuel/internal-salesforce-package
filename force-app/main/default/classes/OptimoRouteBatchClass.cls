/**
 * @description Batch class to synchronize "Ready" Work Orders with the Optimo Route API.
 * * DESIGN PATTERN: Delta Sync
 * This class uses a "Last Run" timestamp to only process records modified since the 
 * previous execution. This ensures scalability and minimizes API overhead.
 * * INTERFACES:
 * - Database.Batchable: Standard batch processing.
 * - Database.Stateful: Allows the 'totalRecordsProcessed' and 'batchStartTime' to persist across chunks.
 * - Database.AllowsCallouts: Required because the helper class performs web service calls.
 */

 public with sharing class OptimoRouteBatchClass implements Database.Batchable<sObject>, Database.Stateful,  Database.AllowsCallouts {
    
    // Member variables persisted across the batch lifecycle via Database.Stateful
    public Integer totalRecordsProcessed = 0;
    public DateTime lastBatchJobExecuted;
    public DateTime batchStartTime;

    /**
     * @description Entry point for Flows or Process Builders.
     * Initiates the batch with the size defined in Custom Settings.
     */
    @InvocableMethod(label='Run Optimo Sync Batch' description='Starts the Work Order to Optimo synchronization.')
    public static void executeOptimoRouteBatch(){
        
        OptimoRoute_Batch_Settings__c settings = OptimoRoute_Batch_Settings__c.getOrgDefaults();
        system.debug('Flow to Batch > lastBatchJobExecuted and  batchSize'+settings.Last_Batch_Job_Executed__c+' > '+settings.Batch_Job_Size__c);

        OptimoRouteBatchClass optimoBatchClass = new OptimoRouteBatchClass(settings.Last_Batch_Job_Executed__c);
        Id jobId = Database.executeBatch(optimoBatchClass, Integer.valueOf(settings.Batch_Job_Size__c));
    }

    /**
     * @description Parameterized constructor.
     * @param lastBatchJobExecuted The timestamp to filter records for delta synchronization.
     */
    public OptimoRouteBatchClass(DateTime lastBatchJobExecuted) {
        this.lastBatchJobExecuted = lastBatchJobExecuted-1; // fetch records modified since the last successful run - 1 day
        this.batchStartTime = System.now(); // Capture start time to prevent data gaps
    }

    /**
     * @description Collects the records to be processed.
     * Filters for Work Orders that are 'Ready' AND modified since the last successful run.
     */

    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id,Services_Needed__c from WorkOrder where lastmodifieddate >= :lastBatchJobExecuted and Status = 'Ready']);
    }

    /**
     * @description Processes each "chunk" of records.
     * Extracts IDs and delegates the API callout logic to the Helper class.
     */

    public void execute(Database.BatchableContext bc, List<WorkOrder> scope){

        if (scope == null || scope.isEmpty()) return;
        
        set<Id> setOfReadyWOrkOrderIds = new Set<Id>();
        set<Id> setOfServiceNeededIds = new Set<Id>();

        // Collect IDs to pass to the bulkified Helper class
        for(WorkOrder wo : scope){
            setOfReadyWOrkOrderIds.add(wo.Id);
            setOfServiceNeededIds.add(wo.Services_Needed__c);
        }

        try{
            // Perform the integration logic and status updates
            WorkOrderHelperClass.createUpdateWOToOptimo(setOfReadyWOrkOrderIds,setOfServiceNeededIds);

            // Increment the counter for the final log summary
            totalRecordsProcessed += scope.size();
        } catch (Exception ex) {
            // Log full error details to help with troubleshooting
            System.debug(LoggingLevel.ERROR, 'Batch Execution Error: ' + ex.getMessage());
        }
    }

    /**
     * @description Finalizes the batch job.
     * Updates the Custom Setting with the start time of this run to prepare for the next delta sync.
     */

    public void finish(Database.BatchableContext bc){

        OptimoRoute_Batch_Settings__c settings = OptimoRoute_Batch_Settings__c.getOrgDefaults();
        settings.Last_Batch_Job_Executed__c = this.batchStartTime;
        upsert settings;

        System.debug('Optimo Sync Batch Finished. Total processed: ' + totalRecordsProcessed);

    }

}