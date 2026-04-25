import { LightningElement } from 'lwc';

export default class SyncWorkOrdersModal extends LightningElement {

    handleStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.dispatchEvent(
                new CustomEvent('closemodal', {
                    bubbles: true,
                    composed: true
                })
            );
        }
    }
}


// import { LightningElement } from 'lwc';

// export default class SyncWorkOrdersModal extends LightningElement {
//     showModal = true;

//     connectedCallback() {
//         this.showModal = true; // reset every load
//     }

//     handleStatusChange(event) {
//         if (event.detail.status === 'FINISHED') {
//             this.closeModal();
//         }
//     }

//     closeModal() {
//         this.showModal = false;
//         window.history.back();
//     }
// }