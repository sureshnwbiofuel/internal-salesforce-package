/**
     * @description Mocks a successful HTTP response (200 OK).
     */
    public class MockHttpResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Assert that the request is set up correctly
            System.assertEquals('POST', req.getMethod(), 'Method should be POST');
            System.assert(req.getEndpoint().contains('bulk_orders'), 'Endpoint should point to bulk_orders');
            System.assertEquals('application/json', req.getHeader('Content-Type'), 'Content type should be JSON');
            
            // Return fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true, "orderId": "12345"}');
            res.setStatusCode(200);
            return res;
        }
        
    }