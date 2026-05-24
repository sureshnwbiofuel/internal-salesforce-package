@isTest
public class MultiSelectSplitterTest {
    
    @isTest
    static void testSplitValues() {
        // 1. Prepare test data
        // We simulate three scenarios in one list to test bulkification:
        // - A standard multi-select string
        // - A null value
        // - An empty string
        List<String> testInputs = new List<String>{
            'Apples;Oranges;Bananas',
            null,
            ''
        };
        
        // 2. Execute the code
        Test.startTest();
        List<List<String>> results = MultiSelectSplitter.splitValues(testInputs);
        Test.stopTest();
        
        // 3. Verify the results
        System.assertEquals(3, results.size(), 'The output list should match the input list size.');
        
        // Assertions for the first input ('Apples;Oranges;Bananas')
        System.assertEquals(3, results[0].size(), 'The first input should be split into 3 individual strings.');
        System.assertEquals('Apples', results[0][0]);
        System.assertEquals('Oranges', results[0][1]);
        System.assertEquals('Bananas', results[0][2]);
        
        // Assertions for the second input (null)
        System.assertEquals(0, results[1].size(), 'A null input should return an empty list.');
        
        // Assertions for the third input ('')
        System.assertEquals(0, results[2].size(), 'An empty string input should return an empty list.');
    }
}