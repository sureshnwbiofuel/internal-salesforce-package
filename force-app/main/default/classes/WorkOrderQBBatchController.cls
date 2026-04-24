public with sharing class WorkOrderQBBatchController {

    public List<Id> selectedIds { get; set; }

    public WorkOrderQBBatchController(ApexPages.StandardSetController controller) {
        selectedIds = new List<Id>();
        
        // 1. Capture the records checked in the List View UI
        List<WorkOrder> selectedRecords = (List<WorkOrder>)controller.getSelected();
        
        if (selectedRecords != null && !selectedRecords.isEmpty()) {
            for (WorkOrder wo : selectedRecords) {
                selectedIds.add(wo.Id);
            }
        } 
        
        // 2. Optional Fallback: Check URL parameters (only if you have a custom URL button)
        if (selectedIds.isEmpty()) {
            String rawIds = ApexPages.currentPage().getParameters().get('ids');
            if (String.isNotBlank(rawIds)) {
                // Note: We cast the split List<String> to List<Id> inside addAll
                selectedIds.addAll((List<Id>)rawIds.split(','));
            }
        }
    }
    
    public PageReference runBatch() {
        if (selectedIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'No records selected. Please go back and select at least one Work Order.'
            ));
            return null;
        }

        try {
            QBO_Batch_Settings__c settings = QBO_Batch_Settings__c.getOrgDefaults();

            Integer batchSize = (settings.Batch_Job_Size__c != null)
                ? Integer.valueOf(settings.Batch_Job_Size__c)
                : 5;
            
            Database.executeBatch(new QBO_InvoiceBatch(selectedIds), batchSize);

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Batch job started successfully for ' + selectedIds.size() + ' records.'
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error starting batch: ' + e.getMessage()
            ));
        }

        return null;
    }
}