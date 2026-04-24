/**
     * @description Mocks a network exception (to test the catch block).
     */
    public class MockHttpResponseExcep implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            CalloutException e = new CalloutException();
            e.setMessage('Read timed out');
            throw e;
        }
    }