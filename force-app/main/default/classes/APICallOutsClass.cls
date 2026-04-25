/**
 * @description Service class dedicated to handling outbound API communications.
 * This class abstracts the complexities of HTTP requests and provides a unified 
 * mechanism for logging every request/response exchange for audit and debugging purposes.
 * * SECURITY NOTE: This class utilizes Named Credentials to manage endpoints and 
 * authentication headers (Client ID/Secret) securely outside of the Apex codebase.
 */

 public with sharing class APICallOutsClass {

    // Constants for cleaner maintenance
    private static final String OPTIMO_NAMED_CRED = 'callout:MuleSoft_Named_Credential';
    private static final String OPTIMO_PATH = '/v1/bulk_orders';
    private static final Integer DEFAULT_TIMEOUT = 120000;

    /**
     * @description A lightweight wrapper to bundle a request and its corresponding 
     * response. This facilitates passing the full "conversation" to the logging service.
     */
    public class HttpExchange {
        public HttpRequest req;
        public HttpResponse res;

        public HttpExchange(HttpRequest rq, HttpResponse rs) {
            this.req = rq;
            this.res = rs;
        }
    }

    /**
     * @description Orchestrates the callout to OptimoRoute via MuleSoft.
     * @param body The JSON payload to be sent.
     * @param relatedIds Set of WorkOrder IDs associated with this request.
     * @return HttpResponse The API response.
     */
    public static HttpResponse optimoRouteCallOut(String body, Set<Id> relatedIds) {
        // Construct the full endpoint using Named Credential
        String endpoint = OPTIMO_NAMED_CRED + OPTIMO_PATH;

        // Perform the generic callout
        HttpExchange exchange = makeAPICallOut(endpoint, 'POST', body);

        // Persist request and response details to the database
        createIntegrationLogs(exchange, relatedIds);

        return exchange.res;
    }

    /**
     * @description Core engine for making network requests.
     * @param endpoint The destination URL (ideally a Named Credential).
     * @param method HTTP Method (POST, GET, etc.).
     * @param body JSON payload.
     * @return HttpExchange containing both Request and Response objects.
     */
    private static HttpExchange makeAPICallOut(String endpoint, String method, String body) {

        // Generate the Correlation ID once per transaction
        String correlationId = UUID.randomUUID().toString().remove('-');

        Http http = new Http();
        HttpRequest request = new HttpRequest();
    

        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Correlation-ID', correlationId); // Pass to MuleSoft
        
        // Note: client_id/secret are typically handled by the External Credential 
        // linked to the Named Credential. If custom headers are required, set them here.
        
        if (String.isNotBlank(body)) {
            request.setBody(body);
        }

        request.setTimeout(DEFAULT_TIMEOUT);

        HttpResponse response;
        try {
            response = http.send(request);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Network Callout Exception: ' + e.getMessage());
            
            // Create synthetic response for logging purposes
            response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('{"error": "Callout Failed", "message": "' + e.getMessage() + '"}');
        }

        return new HttpExchange(request, response);
    }
    
    

    /**
     * @description Persists the details of an HTTP exchange into custom logging objects.
     * Uses a junction object to link a single log to multiple WorkOrder records.
     * @param hx The HttpExchange object containing the Req and Res.
     * @param relatedIds The Salesforce record IDs to link to this log.
     */
    public static void  createIntegrationLogs(HttpExchange hx, Set<Id> relatedIds) {
        
        // Guard clause: Ensure we have data to log
        if (hx == null || hx.req == null || hx.res == null) return;

        try{
            // 1. Initialize the Main Log Entry
            Integration_Logs__c log = new Integration_Logs__c();
            log.Request_Endpoint__c= hx.req.getEndpoint();
            log.Request_Correlation_Id__c = hx.req.getHeader('X-Correlation-ID');
            log.Request_Body__c= hx.req.getBody().left(25000);
            log.Response_Body__c = hx.res.getBody().left(10000);
            log.Status_Code__c = String.valueOf(hx.res.getStatusCode());
            
            // Insert the log header using USER_MODE to enforce Object/Field permissions
            insert as user log;

            // 2. Link the log to specific WorkOrders via a Junction Object
            if (relatedIds != null && !relatedIds.isEmpty()) {
                List<Integration_Logs_Junction__c> junctions = new List<Integration_Logs_Junction__c>();

                for (Id recordId : relatedIds) {
                    junctions.add(new Integration_Logs_Junction__c(
                        Integration_Logs__c = log.Id,
                        Work_Order__c = recordId
                    ));
                }

                // Bulk insert junction records to respect governor limits
                insert as user junctions;
            }
        }
        catch(Exception e){
            // Silent failure for logging to ensure the main business process doesn't roll back
            System.debug(LoggingLevel.ERROR, 'Log Persistence Failed: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }
}