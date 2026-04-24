import { LightningElement,api,wire } from 'lwc';
import getWORecord from '@salesforce/apex/ValidateWOandSyncAPexHandler.getWORecord';

export default class ValidateWOandSyncToOptimoRoute extends LightningElement {

    @api recordId;
    
    tableData = [];
    isValidationSuccess = true;

    
    columns = [
        { label: 'Field Name', fieldName: 'fieldName', sortable: true },
        { label: 'Field Value', fieldName: 'fieldValue', sortable: true }
    ];
    

    connectedCallback() {
        console.log('recordId: ' + this.recordId);
    }

    closeAction(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    @wire(getWORecord, { woRecordId: '$recordId'})
        wiredData({ error, data }) {
            if (data) {
                console.log('data: ' + JSON.stringify(data));
                this.tableData = data.map(item => ({
                fieldName: item.fieldName,
                fieldValue: item.fieldValue
            }));
                // 🔍 Validate: if any fieldValue is blank/null → set to false
                this.isValidationSuccess = !this.tableData.some(row =>
                    row.fieldValue === null ||
                    row.fieldValue === undefined ||
                    row.fieldValue === ''
                );
                console.log('tableData: ' + JSON.stringify(this.tableData));
            } else if (error) {
                console.log('error: ' + JSON.stringify(error));
            }
        }
}