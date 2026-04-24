import { LightningElement, api } from 'lwc';
import runBatch from '@salesforce/apex/QBO_InvoiceBatchController.runBatch';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QboBatchLauncher extends LightningElement {
    @api recordIds;

    handleClick() {
        runBatch({ workOrderIds: this.recordIds })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Batch job started',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}