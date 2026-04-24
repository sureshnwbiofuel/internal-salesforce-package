public class ReverseGeoCodeCalloutQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        Account acc = [Select Id,BillingStreet,BillingCity,BillingState,BillingPostalCode,BillingCountry,BillingLongitude,BillingLatitude from Account where  BillingCity = null and BillingState = null and BillingPostalCode = null and BillingCountry = null and BillingLongitude != null and BillingLatitude != null  limit 1];
        if (acc != null) {
            
            String endpoint = 'https://nominatim.openstreetmap.org/reverse?lat='+acc.BillingLatitude+'&lon='+acc.BillingLongitude+'&format=json';
			HttpRequest req = new HttpRequest();
			req.setEndpoint(endpoint);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req);
			if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // 1. Get the inner 'address' object
                Map<String, Object> addr = (Map<String, Object>) responseMap.get('address');
                
                if (addr != null) {
                    // --- STREET (Combine Number + Road) ---
                    String street = '';
                    if (addr.get('house_number') != null) {
                        street += (String) addr.get('house_number') + ' , ';
                    }
                    if (addr.get('road') != null) {
                        street += (String) addr.get('road');
                    }
                    acc.BillingStreet = street.trim();
            
                    // --- CITY (The tricky part: handle Town/Village/City) ---
                    // Your JSON returned 'town', so we must check for that.
                    if (addr.get('city') != null) {
                        acc.BillingCity = (String) addr.get('city');
                    } else if (addr.get('town') != null) {
                        acc.BillingCity = (String) addr.get('town');
                    } else if (addr.get('village') != null) {
                        acc.BillingCity = (String) addr.get('village');
                    }
            
                    // --- STATE, POSTAL CODE, COUNTRY ---
                    if (addr.get('state') != null) {
                        acc.BillingState = (String) addr.get('state');
                    }
                    if (addr.get('postcode') != null) {
                        acc.BillingPostalCode = (String) addr.get('postcode');
                    }
                    if (addr.get('country') != null) {
                        acc.BillingCountry = (String) addr.get('country');
                    }
                    
                    // IMPORTANT: Update the account to save changes and stop the infinite loop
                    update acc;
                }
            }
            ID jobID = System.enqueueJob(new ReverseGeoCodeCalloutQueueable());
            
           /*System.AsyncOptions options = new System.AsyncOptions();
            // Correct: Assign the integer value directly to the property
            options.MinimumQueueableDelayInMinutes = 1; 
            // The property name in the error message is misleading; it is actually 'MinimumQueueableDelayInMinutes'
            
            // Then use the options when enqueuing the job
            ID jobID = System.enqueueJob(new ReverseGeoCodeCalloutQueueable(), options);*/

        }
    }

}